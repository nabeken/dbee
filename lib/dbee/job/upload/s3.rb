require 'dbee/job'
require 'facter'
require 'fileutils'
require 'right_aws'
require 'uri'

module DBEE
  module Job
    module Upload
      class S3
        extend Job
        attr_accessor :request_id, :request_url, :http, :hostbased_queue

        def self.queue
          @host_based_queue || :encode
        end

        def self.perform(request_id, running_job, args)
          request = Request.new(request_id)
          worker = Facter.value(:fqdn)
          request.start_job(:worker => worker, :running_job => running_job)

          request_data = request.get.body

          # 成果物が存在していることを確認
          upload_file = args["file"]
          unless File.exist?(upload_file)
            request_data["running_job"] = nil
            request.put(request_data)
            raise "File not found. #{upload_file}"
          end

          begin
            # S3へアップロード準備
            s3 = RightAws::S3.new(DBEE::Config::Upload::AMAZON_ACCESS_KEY_ID,
                                 DBEE::Config::Upload::AMAZON_SECRET_ACCESS_KEY)
            upload_bucket = s3.bucket(DBEE::Config::Upload::UPLOAD_BUCKET)
            key = "upload/#{File.basename(upload_file)}"
            response = s3.interface.store_object(
              :bucket => upload_bucket,
              :key    => key,
              :md5    => args["MD5"],
              :data   => File.open(upload_file, "r")
            )

            # expired after a day (86400s)
            public_link = s3.interface.get_link(upload_bucket, key, 86400)
            etag = response["etag"].gsub(/^\[\"\\"(.*)\\\""\]$/) { $1 }

            # MD5が不一致なら例外
            if args["MD5"] != etag
              raise "MD5 checksum does not match. " +
                    "expected: #{args["MD5"]}, got: #{etag}"
            end

            # 終了処理
            request_data["run_list"][0]["output"]["url"] = public_link
            request_data["run_list"][0]["output"]["worker"] = worker
            request.put(request_data)

            # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
            request.delete("running_job")
            puts "Uploading job for request_data##{request.request_id} sucessfully finished."
          rescue
            request_data["running_job"] = nil
            request.put(request_data)
            raise "failed to upload #{args["file"]} to S3. reason: #{$!}"
          end
        end
      end
    end
  end
end
