#!/usr/bin/env ruby
$LOAD_PATH.unshift File.dirname(File.expand_path(__FILE__)) + '/../lib'
require 'resque'
require 'dbee/job'

#
# ./dbee-qnqueuer.rb <input> <job class>
#

def usage
  puts "./#{File.basename(__FILE__)} <input> <job class>"
  exit 1
end

if ARGV.size != 2
  usage
end

# 現在は1台構成なのでinputがファイルシステム上に存在するか確認
if File.exist?(ARGV[0])
  input = ARGV[0]
else
  puts "input \"#{ARGV[0]}\" no such file"
  usage
end

# 引数のjob classが実際に存在するか確認する
begin
  eval ARGV[1] + '.class'
rescue NameError
  puts "job class \"#{ARGV[1]}\" is not defined"
  usage
end

Resque.enqueue(eval(ARGV[1]), input)
