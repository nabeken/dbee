#!/usr/bin/env ruby
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'resque'
require 'dbee/job'
require 'dbee/enqueuer'
require 'facter'
load File.dirname(__FILE__) + '/../config.rb'

#
# ./dbee-qnqueuer.rb <input>
#

def usage
  puts "./#{File.basename(__FILE__)} <input>"
  exit 1
end

if ARGV.size != 1
  usage
end

# このコマンドを実行したホストにファイルが存在しているか確認
if File.exist?(ARGV[0])
  input = Pathname.new(ARGV[0])
else
  puts "input \"#{ARGV[0]}\" no such file"
  usage
end

enqueuer = DBEE::Enqueuer.new(input)

begin
  request_id = enqueuer.post_request
  puts "successfully enqueued #{enqueuer.input.basename}. Request ID: #{request_id}"
  puts "Request: #{DBEE::Config::API_URL}/request/#{request_id}"
  exit 0
rescue
  puts $!
  exit 1
end
