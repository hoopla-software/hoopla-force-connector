require 'savon'
require 'hoopla_force_connector/core_ext/hash'
require 'hoopla_force_connector/sanitizer'

class HooplaForceConnector
  attr_reader :session_id, :server_url, :client
  attr_accessor :should_sanitize

  def self.default_client
    Salesforce.new(SalesforceConfig)
  end

  def self.client_for(session_id, server_url=nil)
    Salesforce.new(SalesforceConfig.merge(:session_id => session_id, :server_url => server_url))
  end

  def initialize(options)
    @session_id = options[:session_id]
    @server_url = options[:server_url]
    @username = options[:username]
    @password = options[:password]
    @api_key = options[:api_key]
    @wsdl = options[:wsdl]
    @should_sanitize = true

    @client = Savon::Client.new @wsdl

    if @session_id && @server_url
      @client.wsdl.soap_endpoint = @server_url
    else
      login
    end
  end

  def login
    response = sanitize(@client.login do |soap|
      soap.body = { "wsdl:username" => @username, "wsdl:password" => @password + @api_key }
    end.to_hash)

    @session_id ||= response[:session_id]
    @client.wsdl.soap_endpoint = response[:server_url]
  end

  def query(query)
    result = __call__ :query, { "wsdl:queryString" => query }

    sanitize(result) + query_more(result)
  end

  def query_more(previous)
    if previous.values.first[:result][:done]
      return []
    end

    locator = previous.values.first[:result][:query_locator]
    result = __call__ :query_more, { "wsdl:QueryLocator" => locator}

    sanitize(result) + query_more(result)
  end

  # Note: Salesforce will bomb out if argument ordering is wrong. We only have one call that
  #       takes multiple arguments, so we'll insert the correct order from the WSDL here
  def retrieve(args)
    __sanitized_call__ :retrieve, args.merge(:order! => ['wsdl:fieldList', 'wsdl:sObjectType', 'wsdl:ID'])
  end

  def method_missing(meth, *args, &block)
    if @client.respond_to?(meth)
      __sanitized_call__ meth, args.last
    else
      super
    end
  end

  def __call__(meth, params = nil)
    result = @client.send(meth) do |soap|
      soap.header = { "wsdl:SessionHeader" => { "wsdl:sessionId" => @session_id } }
      soap.body   = params.map_to_hash { |k, v| [convert_key(k), v] } if params 
    end.to_hash
  end

  def __sanitized_call__(meth, params = nil)
    sanitize(__call__(meth, params))
  end

  def convert_key(key)
    if key.to_s =~ /^wsdl:/ || key.to_s =~ /!$/
      key
    else
      "wsdl:" + key.to_s.camelize(:lower)
    end
  end
  private :convert_key


  def respond_to?(meth)
    super || @client.respond_to?(meth)
  end

  def sanitize(raw)
    @should_sanitize ? Sanitizer.sanitize(raw) : raw
  end

  module ActiveRecordExtensions
    def missing_sf_organization_id?
      !column_names.include?("sf_organization_id")
    rescue Mysql::Error
      # do nothing, because we probably don't even have a db
      # which means that we're probably running migrations
    end

    def salesforce_owned_by(owner, opts={})
      include Salesforce::Owned
      extend Salesforce::OrgScope if owner == :organization && missing_sf_organization_id?

      Salesforce::Owned.establish_ownership(self, owner, opts)
    end

    def owner
      @owner.constantize
    end
  end
end
