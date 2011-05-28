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
"
#{request_data["program"]["filename"]}のエンコード、アップロードが完了しました。
#{args["url"]}

担当: #{args["worker"]}
エンコード開始時刻: #{encode_started_at}
エンコード終了時刻: #{encode_finished_at}
").force_encoding("ASCII-8BIT")
        )
      end
    end
  end
end
