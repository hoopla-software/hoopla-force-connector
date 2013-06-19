require 'test_helper'

class HooplaForceConnectorTest < ActiveSupport::TestCase
  setup do
    @query = "SELECT Name FROM Opportunity"
    @session_id = "pizza!"
    @server_url = "http://pizzahut.com"
    unstub(HooplaForceConnector, :new)
    @sf = HooplaForceConnector.new(:session_id => @session_id, :server_url => @server_url,
                         :wsdl => SalesforceConfig[:wsdl])
    @soap_mock = mock('soap')
    @soap_mock.stubs(:header=)
    @soap_mock.stubs(:body=)
   end

  test "sets the soap endpoint" do
    assert_equal @server_url, @sf.client.globals[:endpoint]
  end

  test "string query with single result" do
    sf_api_response = SalesforceResponses.query_single_user
    @query = "SELECT Name FROM Opportunity"
    @soap_mock.expects(:header=).with({ "wsdl:SessionHeader" => { "wsdl:sessionId" => @session_id }})
    @soap_mock.expects(:body=).with({ "wsdl:queryString" => @query })
    Savon::Client.any_instance.expects(:query).yields(@soap_mock).returns(sf_api_response)
    assert_equal sf_api_response[:query_response][:result][:records][:title], @sf.query(@query)[0][:title]
  end

  test "query will use queryMore when query isn't done" do
    query_response = SalesforceResponses.query_opportunities_not_done
    query_more_response = SalesforceResponses.query_more_opportunities

    Savon::Client.any_instance.expects(:query).yields(@soap_mock).returns(query_response)
    Savon::Client.any_instance.expects(:query_more).yields(@soap_mock).returns(query_more_response)

    @sf.query(@query)
  end

  test "doesn't call login if both session_id and server_url are already available" do
    username, password, api_key = "bob", "password", "api_key"
    Savon::Client.any_instance.expects(:login).never
    @sf = HooplaForceConnector.new(:wsdl => SalesforceConfig[:wsdl],
                         :username => username,
                         :password => password,
                         :api_key  => api_key,
                         :session_id => @session_id,
                         :server_url => @server_url)
  end

  test "logs in first when provided with username, password and api key" do
    username, password, api_key = "bob", "password", "api_key"
    @soap_mock.expects(:body=).with({ "wsdl:username" => username,
                                     "wsdl:password" => password + api_key })
    Savon::Client.any_instance.expects(:login).yields(@soap_mock).returns(SalesforceResponses.login)
    @sf = HooplaForceConnector.new(:wsdl => SalesforceConfig[:wsdl],
                         :username => username,
                         :password => password,
                         :api_key  => api_key)
    assert_equal clean_sf(:login)[:session_id], @sf.session_id
    assert_equal clean_sf(:login)[:server_url], @sf.client.globals[:endpoint]
  end

  test "login with partner credentials but use customer's session id" do
    username, password, api_key = "bob", "password", "api_key"
    @soap_mock.expects(:body=).with({ "wsdl:username" => username,
                                     "wsdl:password" => password + api_key })
    Savon::Client.any_instance.expects(:login).yields(@soap_mock).returns(SalesforceResponses.login)
    @sf = HooplaForceConnector.new(:wsdl => SalesforceConfig[:wsdl],
                         :username => username,
                         :password => password,
                         :api_key  => api_key,
                         :session_id => "abc123")
    assert_equal "abc123", @sf.session_id
    assert_equal clean_sf(:login)[:server_url], @sf.client.globals[:endpoint]
  end
  
  test "runs arbitrary soap operations without body" do
    @soap_mock.expects(:header=).with({ "wsdl:SessionHeader" => { "wsdl:sessionId" => @session_id }})
    Savon::Client.any_instance.expects(:get_user_info).yields(@soap_mock).returns({ :get_user_info_response => { :result => SalesforceResponses.get_user_info }})
    assert_equal SalesforceResponses.get_user_info, @sf.get_user_info
  end

  test "runs arbitrary soap operations with body and override key" do
    @soap_mock.expects(:body=).with({ "wsdl:sObjectType" => "User", "wsdl:SPECIAL" => "special" })
    @soap_mock.expects(:header=).with({ "wsdl:SessionHeader" => { "wsdl:sessionId" => @session_id }})
    Savon::Client.any_instance.expects(:describe_s_object).yields(@soap_mock).returns({ :describe_s_object_response => { :result => "" }})
    assert_equal "", @sf.describe_s_object(:s_object_type => "User", "wsdl:SPECIAL" => "special")
  end

  test "can toggle whether or not to sanitize savon responses" do
    raw = SalesforceResponses.get_user_info
    Savon::Client.any_instance.stubs(:get_user_info).yields(@soap_mock).returns(raw)

    assert_equal clean_sf(:get_user_info), @sf.get_user_info
    @sf.should_sanitize = false
    assert_equal raw, @sf.get_user_info
  end

  test "retrieve enforces argument order" do
    args = { 'wsdl:sObjectType' => "Opportunity", 'wsdl:fieldList' => "Id", 'wsdl:ID' => ["AABBCCDD"] }
    @soap_mock.expects(:body=).with(args.merge(:order! => ['wsdl:fieldList', 'wsdl:sObjectType', 'wsdl:ID']))
    Savon::Client.any_instance.stubs(:retrieve).yields(@soap_mock).returns(SalesforceResponses.retrieve_opportunities)
    @sf.retrieve(args)
  end
end
