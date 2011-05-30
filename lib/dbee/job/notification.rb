# vim:fileencoding=utf-8

require 'dbee/job'
require 'facter'
require 'fileutils'
require 'pony'
require 'nkf'

module DBEE
  module Job
    class Notification
      extend Job
      @queue = :master

      def self.queue_prefix
        ""
      end

      def self.perform(request_id, running_job, args)
        request = Request.new(request_id)
        worker = Facter.value(:fqdn)
        request.start_job(:worker => worker, :running_job => running_job)

        request_data = request.get.body

        # ダウンロードジョブを探す
        download_job = request_data["ran_list"].find do |j|
          j["name"] =~ /^DBEE::Job::Download/
        end
        unless download_job["output"]["job_started_at"].empty?
          download_started_at = Time.mktime(*download_job["output"]["job_started_at"])
          download_finished_at = Time.mktime(*download_job["output"]["job_finished_at"])
          download_size = download_job["output"]["size"]
          # ダウンロードの平均速度 (MB/s)
          download_speed = sprintf("%.3f MB/s", (download_size / (download_finished_at - download_started_at)) / (1000.0 ** 2))
        else
          download_started_at = "N/A"
          download_finished_at = "N/A"
          download_speed = "N/A"
        end

        # アップロードジョブを探す
        upload_job = request_data["ran_list"].find do |j|
          j["name"] =~ /^DBEE::Job::Upload/
        end
        upload_started_at = Time.mktime(*upload_job["output"]["job_started_at"])
        upload_finished_at = Time.mktime(*upload_job["output"]["job_finished_at"])
        upload_size = upload_job["output"]["size"]
        # ダウンロードの平均速度 (MB/s)
        upload_speed = sprintf("%.3f MB/s", (upload_size / (upload_finished_at - upload_started_at)) / (1000.0 ** 2))

        # エンコードジョブを探す
        encode_job = request_data["ran_list"].find do |j|
          j["name"] =~ /^DBEE::Job::Encode::/
        end
        encode_started_at = Time.mktime(*encode_job["output"]["job_started_at"])
        encode_finished_at = Time.mktime(*encode_job["output"]["job_finished_at"])

        Pony.mail(
            :from    => 'nabeken@tknetworks.org',
            :to      => args["to"],
            :charset => 'ISO-2022-JP',
            :headers => {
                "Mime-Version" => "1.0",
                "Content-Transfer-Encoding" => "7bit"
            },
            :subject => "[DBEE]#{request_data["program"]["filename"]}のエンコードが完了しました",
            :body    => NKF.nkf('-Wj',
"#{request_data["program"]["filename"]}のエンコード、アップロードが完了しました。
#{args["url"]}

担当: #{args["worker"]}
ダウンロード開始時刻: #{download_started_at}
ダウンロード終了時刻: #{download_finished_at}
ダウンロード平均速度(MB/s): #{download_speed}
アップロード開始時刻: #{upload_started_at}
アップロード終了時刻: #{upload_finished_at}
アップロードロード平均速度(MB/s): #{upload_speed}
エンコード開始時刻: #{encode_started_at}
エンコード終了時刻: #{encode_finished_at}
").force_encoding("ASCII-8BIT")
        )
      end
    end
  end
end
