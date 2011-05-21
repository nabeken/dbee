# vim:fileencoding=utf-8

require 'dbee/digest'
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

        puts "start downloading metadata from #{url}.json.."
        # まずメタデータを取得する (ファイルには保存せずメモリ上へ展開)
        response = Request.get("#{url}.json")
        if response.status != 200
          request_data["running_job"] = nil
          request.put(request_data)
          raise "failed to download from #{url}.json. got #{response.status}"
        end
        metadata = JSON.parse(response.content)

        # 終了処理
        closer = Proc.new do |args|
          puts "....finished"

          request_data["run_list"][0]["output"]["file"] = args[:file]
          request_data["run_list"][0]["output"]["worker"] = worker
          request_data["run_list"][0]["output"]["is_copied"] = args[:is_copied]

          # 次のジョブも同一ノードで実行してほしい
          request_data["run_list"][0]["output"]["next_same_node"] = true
          request.put(request_data)

          # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
          request.delete("running_job")
          puts "Downloading job for request##{request.request_id} sucessfully finished."
        end

        # material_node == workerなら同一マシンなのでダウンロードしない
        if request_data["material_node"] == worker
          # ダウンロードしないのでもとの場所に存在している
          puts "material is on this node. do nothing..."
          closer.call(:file => "#{DBEE::Config::MATERIAL_DIR}/#{filename}", :is_copied => false)
          return
        end

        # ファイルが存在していて、かつハッシュ値が同じならダウンロードしない
        download_file = "#{download_dir}/#{filename}"
        if File.exist?(download_file)
          puts "material found..."
          digest = calc_digest(download_file)
          if metadata["SHA256"] == digest.hexdigest
            puts "and match SHA256. do nothing..."
            closer.call(:file => download_file, :is_copied => true)
            return
          else
            puts "and does not match SHA256. try to download..."
          end
        end

        puts "start downloading material from #{url} to #{download_file}...."
        f = File.open(download_file, "wb")
        response = Request.get(url) do |data|
          f << data
        end
        f.close

        if response.status != 200
          File.unlink(download_file)
          request_data["running_job"] = nil
          request.put(request_data)
          raise "failed to download from #{url}. got #{response.status}"
        end

        # SHA256でダウンロードした素材を確かめる
        puts "Calculating SHA256 for #{download_file}...."
        digest = FileDigest::SHA256.digest(download_file)
        if metadata["SHA256"] != digest.hexdigest
          File.unlink(download_file)
          request_data["running_job"] = nil
          request.put(request_data)
          raise "downloaded file #{download_file} does not match SHA256 checksums.\n" +
                "expected: #{metadata["SHA256"]}, got #{digest.hexdigest}"
        end
        closer.call(:file => download_file, :is_copied => true)
      end
    end
  end
end
