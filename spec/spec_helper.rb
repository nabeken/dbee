require 'simplecov'
SimpleCov.start 'rails' do
  add_filter "/vendor/"
end

Encoding.default_external = "UTF-8" if defined? Encoding
Encoding.default_internal = "UTF-8" if defined? Encoding

require 'sinatra'
require 'rack/test'
require 'rspec'
require 'rspec/autorun'
require 'rspec/mocks/standalone'
require 'digest/sha1'

load File.dirname(__FILE__) + '/../config.rb'

set :environment, :test
set :run, false
set :raise_erros, true
set :logging, false

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  #conf.mock_with :mocha
end

def app
  @app
end
