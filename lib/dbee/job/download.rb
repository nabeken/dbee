require 'dbee/job'
require 'facter'
require 'fileutils'
require 'uri'

# initialize facter
Facter.to_hash

module DBEE
  module Job
    class Download
      extend Job

      attr_accessor :request_id, :request_url, :http
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
        filename = request["program"]["filename"]
        url = URI.encode("#{args["base_url"]}#{filename}")
        FileUtils.mkdir_p(download_dir) unless File.exists?(download_dir)
        download_file = "#{download_dir}/#{filename}"

        puts "start downloading metadata from #{url}.json.."
        # まずメタデータを取得する (ファイルには保存せずメモリ上へ展開)
        response = @http.get("#{url}.json")
        if response.status != 200
          request["running_job"] = nil
          put_request(request)
          raise "failed to download from #{url}.json. got #{response.status}"
        end
        metadata = JSON.parse(response.content)

        puts "start downloading material from #{url} to #{download_file}...."
        f = File.open(download_file, "wb")
        response = @http.get(url) do |data|
          f << data
        end
        f.close

        if response.status != 200
          File.unlink(download_file)
          request["running_job"] = nil
          put_request(request)
          raise "failed to download from #{url}. got #{response.status}"
        end

        puts "Calculating SHA256 for #{download_file}...."
        digest = Digest::SHA256.new
        File.open(download_file, 'r') do |f|
          buf = String.new
          while f.read(1024 * 8, buf)
            digest << buf
          end
        end

        # SHA256でダウンロードした素材を確かめる
        if metadata["SHA256"] != digest.hexdigest
          File.unlink(download_file)
          request["running_job"] = nil
          put_request(request)
          raise "downloaded file #{download_file} does not match SHA256 checksums." +
                "expected: #{metadata["SHA256"]}, got #{digest.hexdigest}"
        end

        puts "....finished"

        request["run_list"][0]["output"]["file"] = download_file
        request["run_list"][0]["output"]["worker"] = worker

        # 次のジョブも同一ノードで実行してほしい
        request["run_list"][0]["output"]["next_same_node"] = true
        put_request(request)

        # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
        delete_request("running_job")
        puts "Downloading job for request##{@request_id} sucessfully finished."
      end
    end
  end
end
