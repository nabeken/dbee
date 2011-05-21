#!/usr/bin/env ruby
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
Encoding.default_external = "UTF-8" if defined? Encoding
Encoding.default_internal = "UTF-8" if defined? Encoding

require 'resque'
require 'dbee/job'
require 'dbee/enqueuer'
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
  response = enqueuer.post_request
  puts "successfully enqueued #{enqueuer.input.basename} in ##{response.request_id}"
  puts "URL: #{response.url}"
  exit 0
rescue
  puts $!
  exit 1
end

# vim:fileencoding=utf-8
