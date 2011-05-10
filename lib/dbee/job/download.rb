# vim:fileencoding=utf-8

require 'facter'
require 'fileutils'
require 'uri'

module DBEE
  module Job
    class Download
      extend Job

      attr_accessor :request
      @queue = :all_worker

      def self.queue_prefix
        ""
      end

      def self.perform(request_id, running_job, args)
        request = Request.new(request_id)
        worker = Facter.value(:fqdn)
        request.start_job(:worker => worker, :running_job => running_job)

        request_data = request.get.body

        # URLからダウンロードして保存する
        download_dir = "#{DBEE::Config::Encode::OUTPUT_DIR}/download"
        filename = request_data["program"]["filename"]
        url = URI.encode("#{args["base_url"]}#{filename}")
        FileUtils.mkdir_p(download_dir) unless File.exists?(download_dir)
        download_file = "#{download_dir}/#{filename}"

        puts "start downloading metadata from #{url}.json.."
        # まずメタデータを取得する (ファイルには保存せずメモリ上へ展開)
        response = request.http.get("#{url}.json")
        if response.status != 200
          request_data["running_job"] = nil
          request.put(request_data)
          raise "failed to download from #{url}.json. got #{response.status}"
        end
        metadata = JSON.parse(response.content)

        puts "start downloading material from #{url} to #{download_file}...."
        f = File.open(download_file, "wb")
        response = request.http.get(url) do |data|
          f << data
        end
        f.close

        if response.status != 200
          File.unlink(download_file)
          request_data["running_job"] = nil
          request.put(request_data)
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
          request_data["running_job"] = nil
          request.put(request_data)
          raise "downloaded file #{download_file} does not match SHA256 checksums." +
                "expected: #{metadata["SHA256"]}, got #{digest.hexdigest}"
        end

        puts "....finished"

        request_data["run_list"][0]["output"]["file"] = download_file
        request_data["run_list"][0]["output"]["worker"] = worker

        # 次のジョブも同一ノードで実行してほしい
        request_data["run_list"][0]["output"]["next_same_node"] = true
        request.put(request_data)

        # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
        request.delete("running_job")
        puts "Downloading job for request##{request.request_id} sucessfully finished."
      end
    end
  end
end
