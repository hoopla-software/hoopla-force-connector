require 'test/unit'
require 'mocha'
require 'active_support/test_case'
require 'support/salesforce_responses'

$:.unshift File.dirname(__FILE__) + '/../lib'
require 'hoopla_force_connector'

SalesforceConfig = {
  :wsdl => File.dirname(__FILE__) + '/support/partner.wsdl'
}

class ActiveSupport::TestCase
  def unstub(stubbee, method)
    Mocha::Mockery.instance.stubba.stubba_methods.select { |s| s.stubbee == stubbee && s.method == method.to_s }.each(&:unstub)
  end

  def clean_sf(call)
    sanitize_sf(SalesforceResponses.send(call))
  end

  def sanitize_sf(raw)
    HooplaForceConnector::Sanitizer.sanitize(raw)
  end
end
