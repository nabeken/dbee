#!/usr/bin/env ruby
$LOAD_PATH.unshift File.dirname(__FILE__) + '/lib'
require 'resque/server'
load File.expand_path(File.dirname(__FILE__) + '/config.rb')
require 'dbee/app'

use Rack::ShowExceptions
run Rack::URLMap.new \
  "/"       => DBEE::App.new,
  "/resque" => Resque::Server.new
