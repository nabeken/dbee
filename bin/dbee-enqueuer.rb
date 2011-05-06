#!/usr/bin/env ruby
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'resque'
require 'dbee/job'
require 'facter'
load File.dirname(__FILE__) + '/../config.rb'

#
# ./dbee-qnqueuer.rb <input> <job class>
#

def usage
  puts "./#{File.basename(__FILE__)} <input>"
  exit 1
end

if ARGV.size != 1
  usage
end

module DBEE
  class Enqueuer
    attr_accessor :request_id, :http, :input, :material

    def initialize(input)
      proxy = ENV['HTTP_PROXY'] || ENV['http_proxy'] || nil
      @http = HTTPClient.new(proxy)
      @input = input
      @request_url = "#{DBEE::Config::API_URL}/request/"
      # ダウンロードジョブの関係上、任意の場所に置いたまま処理はできないので
      # MATERIAL_DIR以下にない場合はシンボリックリンクを張る
      @material = Pathname.new("#{DBEE::Config::MATERIAL_DIR}/#{input.basename}")
      unless File.exist?(material)
        @material.symlink(input)
      end
    end

    def get_request_json
      # request api用にJSONを生成する
      request_json = {
        "requester"     => Facter.value(:fqdn),
        "material_node" => Facter.value(:fqdn),
        "run_list" => [
          {
            "name" => "DBEE::Job::Download",
            "args" => {
              "base_url" => DBEE::Config::MATERIAL_BASE_URL
            }
          },
          {
            "name" => "DBEE::Job::Encode::IPAD",
            "args" => {}
          },
          {
            "name" => "DBEE::Job::Upload::S3",
            "args" => {}
          },
          {
            "name" => "DBEE::Job::Notification",
            "args" => {
              "to" => "nabeken.ipad@tknetworks.org"
            }
          }
        ],
        "program" => {
          "name"     => "",
          "ch"       => "",
          "filename" => @input.basename
        }
      }.to_json
    end

    # 成功時はrequest_idを返す
    def post_request
      response = @http.post("#{@request_url}", get_request_json)

      # 成功時は303 see otherが返る
      if response.status != 303
        raise "failed to POST request. got #{response.status}"
      end
      response.headers["Location"].split('/').last
    end
  end
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
