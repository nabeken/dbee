#!/usr/bin/env ruby
$LOAD_PATH.unshift File.dirname(__FILE__) + '/lib'
require 'resque/server'
load File.expand_path(File.dirname(__FILE__) + '/config.rb')
require 'dbee/app'
require 'dbee/app/job'
require 'dbee/app/request'

use Rack::ShowExceptions

map '/' do
  use Rack::Static, :urls => ["/coverage"], :root => "/home/nabeken/work/dbee"
  run DBEE::App.new
end

map '/job' do
  run DBEE::App::Job.new
end
map '/request' do
  run DBEE::App::Request.new
end
map '/resque' do
  run Resque::Server.new
end
