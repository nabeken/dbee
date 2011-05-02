require 'dbee/job'
require 'facter'
require 'fileutils'
require 'right_aws'
require 'uri'

# initialize facter
Facter.to_hash

module DBEE
  module Job
    module Upload
      class S3
        extend Job
        attr_accessor :request_id, :request_url, :http, :hostbased_queue

        def self.queue
          @host_based_queue || :encode
        end

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

          # 成果物が存在していることを確認
          upload_file = output["file"]
          unless File.exist?(upload_file)
            request["running_job"] = nil
            put_request(request)
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
              :md5    => output["MD5"],
              :data   => File.open(upload_file, "r")
            )

            # expired after a day
            public_link = s3.interface.get_link(upload_bucket, key)
            #public_link = URI.parse(upload_bucket.key(key, true).first.public_link)
            #public_link = "#{_public_link.scheme}://#{_public_link.host}/#{key}"
            etag = response["etag"].gsub(/^\[\"\\"(.*)\\\""\]$/) { $1 }

            puts "MD5: #{output["MD5"]}"
            puts "ETAG: #{etag}"

            # 終了処理
            request["run_list"][0]["output"]["url"] = public_link
            request["run_list"][0]["output"]["worker"] = worker
            put_request(request)

            # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
            delete_request("running_job")
            puts "Uploading job for request##{@request_id} sucessfully finished."
          rescue
            request["running_job"] = nil
            put_request(request)
            raise "failed to upload #{output["file"]} to S3. reason: #{$!}"
          end
        end
      end
    end
  end
end
