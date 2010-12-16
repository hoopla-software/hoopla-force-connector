require 'rubygems'
require 'bundler'
Bundler.setup

require 'rake'
require 'rake/gempackagetask'
require 'rake/testtask'
load    'hoopla_force_connector.gemspec'

Rake::GemPackageTask.new($spec) do |t|
  t.need_tar = true
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

