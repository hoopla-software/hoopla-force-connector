$spec = Gem::Specification.new do |s|
  s.name = "hoopla_force_connector"
  s.version = '0.0.1'
  s.summary = "Ruby interface for the Salesforce API"

  s.authors  = ['Trotter Cashion', 'Mat Schaffer']
  s.email    = ['cashion@gmail.com', 'mat@schaffer.me']
  s.homepage = 'http://www.openmarket.com'

  s.add_development_dependency 'mocha'
  s.add_development_dependency 'i18n'
  s.add_development_dependency 'activesupport'

  s.add_dependency 'hoopla-savon'

  s.files = Dir['lib/**']
  s.rubyforge_project = 'nowarning'
end
