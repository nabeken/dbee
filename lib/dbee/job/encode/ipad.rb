require 'dbee/job/encode'
require 'facter'
require 'digest/md5'
require 'digest/sha2'

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
          request = Request.new(request_id)
          worker = Facter.value(:fqdn)
          request.start_job(:worker => worker, :running_job => running_job)

          request_data = request.get.body

          # 前のジョブの成果物(素材)の場所を取得
          source = output["file"]
          puts "start encoding #{source}..."

          config = Encode::Config.new
          config.source = source
          config.size = "1280x720"
          config.dir = "iPad"

          unless system("ffmpeg" + config.get_cmd + "\"" + config.output + "\"" + " >/dev/null 2>&1")
            # ffmpegが失敗した場合
            File.unlink(config.output)
            request_data["running_job"] = nil
            request.put(request_data)
            raise "request_data #{request.request_id} failed."
          end
          puts "encode successfully finished"

          puts "Calculating MD5 for #{config.output}...."
          # 成果物のハッシュ値を計算 (S3向けにひとまずMD5)
          digest = Digest::MD5.new
          File.open(config.output, "r") do |f|
            buf = String.new
            while f.read(1024 * 8, buf)
              digest << buf
            end
          end
          puts "...finished."

          # request_data APIへ報告する
          job = request_data["run_list"].first
          job["output"]["MD5"] = digest.hexdigest
          job["output"]["file"] = config.output
          job["output"]["worker"] = worker
          # 次のジョブも同一ノードで実行してほしい
          job["output"]["next_same_node"] = true
          # リクエスト更新
          request.put(request_data)

          # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
          request.delete("running_job")
          puts "Encoding job for request_data##{request.request_id} sucessfully finished."
        end
      end
    end
  end
end
