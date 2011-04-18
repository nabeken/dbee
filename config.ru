#!/usr/bin/env ruby
$LOAD_PATH.unshift File.dirname(__FILE__) + '/lib'
require 'resque/server'
load File.expand_path(File.dirname(__FILE__) + '/config.rb')
require 'dbee/app'
require 'dbee/app/job'
require 'dbee/app/request'

use Rack::ShowExceptions
run Rack::URLMap.new \
  "/"        => DBEE::App.new,
  "/job"     => DBEE::App::Job.new,
  "/request" => DBEE::App::Request.new,
  "/resque"  => Resque::Server.new
