require 'dbee/job'
require 'facter'
require 'fileutils'
require 'digest/sha2'
require 'pathname'

module DBEE
  module Job
    class GenerateMetadata
      extend Job
      attr_accessor :request_id, :request_url, :http, :hostbased_queue

      def self.queue
        @host_based_queue || :metadata
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

        basename = request["program"]["filename"]
        filename = Pathname.new("#{DBEE::Config::MATERIAL_DIR}/#{basename}")

        unless File.exist?(filename)
          request["running_job"] = nil
          put_request(request)
          raise "material not found"
        end

        # すでにmetadataが生成済みならそのまま終了
        if File.exist?("#{filename}.json")
          puts "metadata for #{basename} found. skipped...."
        else
          puts "Calculating SHA256 for #{basename}...."
          digest = Digest::SHA256.new
          File.open(filename, 'r') do |f|
            buf = ''
            while f.read(1024 * 8, buf)
              digest << buf
            end
          end

          # JSONの生成
          output = {
            "filename" => basename,
            "size"     => filename.size,
            "SHA256"   => digest.hexdigest,
            "mtime"    => filename.mtime,
            "ctime"    => filename.ctime
          }

          File.open("#{filename}.json", 'w') do |f|
            f.puts output.to_json
          end
        end

        puts "...finished!"

        # 次のジョブはどこでもよい
        request["run_list"][0]["output"]["next_same_node"] = false

        # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
        delete_request("running_job")
        puts "Generating metadata for #{basename} sucessfully finished."
      end
    end
  end
end
