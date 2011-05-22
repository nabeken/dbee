# vim:fileencoding=utf-8

require 'dbee/request'
require 'facter'

module DBEE
  class Enqueuer
    attr_accessor :request_id, :http, :input, :material

    def initialize(input)
      proxy = ENV['HTTP_PROXY'] || ENV['http_proxy'] || nil
      @input = input
      # ダウンロードジョブの関係上、任意の場所に置いたまま処理はできないので
      # MATERIAL_DIR以下にない場合はシンボリックリンクを張る
      @material = Pathname.new("#{DBEE::Config::MATERIAL_DIR}/#{input.basename}")
      unless File.exist?(material)
        @material.symlink(input)
      end
    end

    def get_request_json
      # request api用にJSONを生成する
      {
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
            "args" => {
              "file"   => @input,
              "worker" => Facter.value(:fqdn)
            }
          },
          {
            "name" => "DBEE::Job::Upload::DAV",
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

    def post_request
      Request.post(get_request_json)
    end
  end
end

