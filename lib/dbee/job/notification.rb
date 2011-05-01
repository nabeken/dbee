# vim:fileencoding=utf-8

require 'dbee/job'
require 'facter'
require 'fileutils'
require 'pony'
require 'nkf'

# initialize facter
Facter.to_hash

module DBEE
  module Job
    class Notification
      extend Job
      @queue = :notification

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

        Pony.mail(
            :from    => 'nabeken@tknetworks.org',
            :to      => args["to"],
            :charset => 'ISO-2022-JP',
            :headers => {
                "Mime-Version" => "1.0",
                "Content-Transfer-Encoding" => "7bit"
            },
            :subject => "[DBEE]#{request["program"]["filename"]}のエンコードが完了しました",
            :body    => NKF.nkf('-Wj',
"
#{request["program"]["filename"]}のエンコード、アップロードが完了しました。
#{output["url"]}

エンコード開始時刻:
エンコード終了時刻:
素材ファイルサイズ:
アップロードファイルサイズ:").force_encoding("ASCII-8BIT")
        )
      end
    end
  end
end
