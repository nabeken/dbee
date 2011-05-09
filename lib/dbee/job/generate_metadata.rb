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

      def self.perform(request_id, running_job, args)
        request = Request.new(request_id)
        worker = Facter.value(:fqdn)
        request.start_job(:worker => worker, :running_job => running_job)

        request_data = request.get.body

        basename = request_data["program"]["filename"]
        filename = Pathname.new("#{DBEE::Config::MATERIAL_DIR}/#{basename}")

        unless File.exist?(filename)
          request_data["running_job"] = nil
          request.put(request_data)
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
            while f.read(1024 * 1024 *  8, buf)
              digest << buf
            end
          end

          # JSONの生成
          json = {
            "filename" => basename,
            "size"     => filename.size,
            "SHA256"   => digest.hexdigest,
            "mtime"    => filename.mtime,
            "ctime"    => filename.ctime
          }

          File.open("#{filename}.json", 'w') do |f|
            f.puts json.to_json
          end
        end

        puts "...finished!"

        # 次のジョブはどこでもよい
        request_data["run_list"][0]["output"]["next_same_node"] = false

        # 最後にrunning_jobをDELETEしてジョブの正常終了を通知
        request.delete("running_job")
        puts "Generating metadata for #{basename} sucessfully finished."
      end
    end
  end
end
