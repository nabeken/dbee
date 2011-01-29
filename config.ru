#!/usr/bin/env ruby
$LOAD_PATH.unshift File.dirname(__FILE__) + '/lib'
require 'resque/server'
require 'dbee/app'

use Rack::ShowExceptions
run Rack::URLMap.new \
  "/"       => DBEE::App.new,
  "/resque" => Resque::Server.new
