# coding:utf-8

require 'dbee/digest'
require 'dbee/job/encode'
require 'facter'

module DBEE
  module Job
    module Encode
      class IPAD
        extend Job
        attr_accessor :hostbased_queue

        def self.queue_prefix
          "encode_"
        end

        def self.queue
          @host_based_queue || :all_worker
        end

        def self.perform(request_id, running_job, args)
          request = Request.new(request_id)
          worker = Facter.value(:fqdn)
          request.start_job(:worker => worker, :running_job => running_job)

          request_data = request.get.body

          # 前のジョブの成果物(素材)の場所を取得
          source = args["file"]
          puts "start encoding #{source}..."

          config = Encode::Config.new
          config.source = source
          config.size = "1280x720"
          config.dir = "iPad"

          # 実行前に保存先のディレクトリがなければ作成
          config.mk_save_dir

          cmd = "ffmpeg #{config.get_cmd} \"#{config.output}\" >/dev/null 2>&1"
          puts cmd
          encode_started_at = Time.now
          unless system(cmd)
            # ffmpegが失敗した場合
            File.unlink(config.output) if File.exists?(config.output)
            # 素材のコピーの場合は削除していたが、コンテンツに問題がなければ置いておく？
            request_data["running_job"] = nil
            request.put(request_data)
            raise "request_data #{request.request_id} failed."
          end
          puts "encode successfully finished"
          encode_finished_at = Time.now

          puts "Calculating MD5 for #{config.output}...."
          # 成果物のハッシュ値を計算
          digest_md5 = FileDigest::MD5.digest(config.output)
          digest_sha256 = FileDigest::SHA256.digest(config.output)
          puts "...finished."

          # 素材のコピーの場合は削除する
          if args["is_copied"]
            puts "Remove copied materials...."
            File.unlink(source)
          end

          # request_data APIへ報告する
          job = request_data["run_list"].first
          job["output"]["MD5"] = digest_md5.hexdigest
          job["output"]["SHA256"] = digest_sha256.hexdigest
          job["output"]["file"] = config.output
          job["output"]["worker"] = worker
          job["output"]["job_started_at"] = encode_started_at.to_a
          job["output"]["job_finished_at"] = encode_finished_at.to_a
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
