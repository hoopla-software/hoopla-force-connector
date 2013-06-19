require 'savon'
require 'hoopla_force_connector/core_ext/hash'
require 'hoopla_force_connector/sanitizer'

class HooplaForceConnector
  attr_reader :session_id, :server_url, :client, :proxy_uri
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
    @proxy_uri = options[:proxy]
    @should_sanitize = true

    if @session_id && @server_url
      @client = Savon.client(client_options)
    else
      login
    end
  end

  def login
    login_options = {:wsdl => @wsdl}
    unless proxy_uri.nil?
      login_options[:proxy] = proxy_uri
    end
    @client = Savon.client(login_options)
    response = sanitize(@client.login({ "tns:username" => @username, "tns:password" => @password + @api_key }).to_hash)

    @session_id ||= response[:session_id]
    @client = Savon.client(client_options)
  end

  def query(query)
    result = __call__ :query, { "tns:queryString" => query }

    sanitize(result.body) + query_more(result.body)
  end

  def query_more(previous)
    if previous.values.first[:result][:done]
      return []
    end

    locator = previous.values.first[:result][:query_locator]
    result = __call__ :query_more, { "tns:QueryLocator" => locator}

    sanitize(result.body) + query_more(result.body)
  end

  # Note: Salesforce will bomb out if argument ordering is wrong. We only have one call that
  #       takes multiple arguments, so we'll insert the correct order from the WSDL here
  def retrieve(args)
    __sanitized_call__ :retrieve, args.merge(:order! => ['wsdl:fieldList', 'wsdl:sObjectType', 'wsdl:ID'])
  end

  def method_missing(meth, *args, &block)
    if @client.operations.include? meth
      __sanitized_call__ meth, args.last
    else
      super
    end
  end

  def __call__(meth, params = nil)
    message = params.nil? ? {} : params.map_to_hash { |k, v| [convert_key(k), v] }
    result = @client.call(meth.to_sym, :message => message)
  end

  def __sanitized_call__(meth, params = nil)
    sanitize(__call__(meth, params).body)
  end

  def convert_key(key)
    if key.to_s =~ /^tns:/ || key.to_s =~ /!$/
      key
    else
      "tns:" + key.to_s.camelize(:lower)
    end
  end
  private :convert_key


  def respond_to?(meth)
    super || @client.operations.include?(meth)
  end

  def sanitize(raw)
    @should_sanitize ? Sanitizer.sanitize(raw) : raw
  end

  def client_options
    out = { :wsdl => @wsdl,
            :endpoint => @server_url,
            :soap_header => { "tns:SessionHeader" => { "tns:sessionId" => @session_id } },
            :read_timeout => 200
    }
    unless proxy_uri.nil?
      out[:proxy] = proxy_uri
    end

    out
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
