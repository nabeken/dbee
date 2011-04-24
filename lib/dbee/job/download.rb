require 'dbee/job'
require 'facter'
require 'fileutils'

# initialize facter
Facter.to_hash

module DBEE
  module Job
    class Download
      extend Job
      @queue = :download

      def self.perform(request_id, running_job, args, output = nil)
        @request_id = request_id
        @request_url = "#{DBEE::Config::API_URL}/request/#{@request_id}"
        proxy = ENV['HTTP_PROXY'] || ENV['http_proxy'] || nil
        @http = HTTPClient.new(proxy)

        # Request APIへジョブ開始を通知する
        # running_job, workerを更新する
        worker = Facter.fqdn
        put_request("running_job", running_job)
        put_request("worker", worker)

        request = get_request

        # URLからダウンロードして保存する
        download_dir = "#{DBEE::Config::Encode::OUTPUT_DIR}/download"
        FileUtils.mkdir_p(download_dir) unless File.exists?(download_dir)
        download_file = "#{download_dir}/#{request["program"]["filename"]}"
        puts "start downloading from #{args["url"]} to #{download_file}...."
        File.open(download_file, "wb") do |f|
          @http.get(args["url"]) do |data|
            puts "downloading...."
            f << data
          end
        end
        puts "....finished"
        request["run_list"][0]["output"]["file"] = download_file
        request["run_list"][0]["output"]["worker"] = worker
        # 次のジョブも同一ノードで実行してほしい
        request["run_list"][0]["output"]["next_same_node"] = true
        put_request(request)

        # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
        delete_request("running_job")
        puts "Download job for request##{@request_id} sucessfully finished."
      end
    end
  end
end
