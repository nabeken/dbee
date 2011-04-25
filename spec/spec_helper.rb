require 'simplecov'
SimpleCov.start 'rails'

Encoding.default_external = "UTF-8" if defined? Encoding
Encoding.default_internal = "UTF-8" if defined? Encoding

require 'sinatra'
require 'rack/test'
require 'rspec'
require 'rspec/autorun'
load File.dirname(__FILE__) + '/../config.rb'

set :environment, :test
set :run, false
set :raise_erros, true
set :logging, false

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

def app
  @app
end
