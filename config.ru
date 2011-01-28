#!/usr/bin/env ruby
$LOAD_PATH.unshift File.dirname(__FILE__) + '/lib'
require 'dbee/app'
require 'resque/server'

use Rack::ShowExceptions
run Rack::URLMap.new \
  "/"       => DBEE::App.new,
  "/resque" => Resque::Server.new
