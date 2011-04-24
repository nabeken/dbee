require 'dbee/job/encode'
require 'facter'

# initialize facter
Facter.to_hash

module DBEE
  module Job
    module Encode
      class IPAD
        extend Job
        attr_accessor :hostbased_queue

        def self.queue
          @host_based_queue || :encode
        end

        def self.perform(request_id, running_job, args, output)
          @request_id = request_id
          @request_url = "#{DBEE::Config::API_URL}/request/#{@request_id}"
          proxy = ENV['HTTP_PROXY'] || ENV['http_proxy'] || nil
          @http = HTTPClient.new(proxy)

          # Request APIへジョブ開始を通知する
          # running_job, workerを更新する
          worker = Facter.fqdn
          #running_job = "DBEE::Job::Encode::IPAD"
          put_request("running_job", running_job)
          put_request("worker", worker)

          # Request APIから情報を取得する
          request = get_request

          # 前のジョブの成果物(素材)の場所を取得
          source = output["file"]
          puts "start encoding #{source}..."

          config = Encode::Config.new
          config.source = source
          config.size = "1280x720"
          config.dir = "iPad"
          config.set_programid

          unless system("ffmpeg" + config.get_cmd)
            # ffmpegが失敗した場合
            request["running_job"] = nil
            put_request(request)
            raise "Request #{@request_id} failed."
          end
          puts "encode successfully finished"
          # Request APIへ報告する
          job = request["run_list"].first
          job["output"]["file"] = config.output
          job["output"]["worker"] = worker
          # 次のジョブも同一ノードで実行してほしい
          job["output"]["next_same_node"] = true
          # リクエスト更新
          put_request(request)

          # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
          delete_request("running_job")
          puts "Encode job for request##{@request_id} sucessfully finished."
        end
      end
    end
  end
end