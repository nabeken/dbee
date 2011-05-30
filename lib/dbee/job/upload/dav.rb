# vim:fileencoding=utf-8

require 'dbee/job'
require 'dbee/dav'
require 'facter'
require 'fileutils'
require 'right_aws'
require 'uri'

module DBEE
  module Job
    module Upload
      class DAV
        extend Job
        attr_accessor :request_id, :request_url, :http, :hostbased_queue

        def self.queue_prefix
          "upload_"
        end

        def self.queue
          @host_based_queue
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
            # WebDAV領域へアップロード準備
            dav = DBEE::DAVAccess.new(DBEE::Config::HTTP_USER,
                                      DBEE::Config::HTTP_PASSWORD)

            key = File.basename(upload_file)
            upload_started_at = Time.now
            dav.put(key, File.open(upload_file, "r"))
            upload_finished_at = Time.now

            # SHA256が不一致なら削除して例外
            sha256 = dav.propget(key, "SHA256")
            if args["SHA256"] != sha256
              dav.delete(key)
              raise "SHA256 checksum does not match. " +
                    "expected: #{args["SHA256"]}, got: #{sha256}"
            end

            # 終了処理
            request_data["run_list"][0]["output"]["url"] = dav.get_full_url(key)
            request_data["run_list"][0]["output"]["worker"] = worker
            request_data["run_list"][0]["output"]["size"] = File.size(upload_file)
            request_data["run_list"][0]["output"]["job_started_at"] = upload_started_at.to_a
            request_data["run_list"][0]["output"]["job_finished_at"] = upload_finished_at.to_a
            request.put(request_data)

            # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
            request.delete("running_job")
            puts "Uploading job for request_data##{request.request_id} sucessfully finished."
          rescue
            request_data["running_job"] = nil
            request.put(request_data)
            raise "failed to upload #{args["file"]} to WebDAV. reason: #{$!}"
          end
        end
      end
    end
  end
end
