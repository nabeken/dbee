# vim:fileencoding=utf-8

require 'dbee/job'
require 'facter'
require 'fileutils'
require 'digest/sha2'
require 'pathname'
require 'tmpdir'

module DBEE
  module Job
    class GenerateMetadata
      extend Job
      attr_accessor :request_id, :request_url, :http, :hostbased_queue

      def self.queue_prefix
        "metadata_"
      end

      def self.queue
        @host_based_queue
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

        # 一時ディレクトリを作る
        Dir.mktmpdir("dbee-") do |dir|
          aac = "#{dir}/#{filename.basename}.aac"
          # まずTSからAACだけ抜く
          puts "Extracting audio track from material...."
          unless system("ffmpeg -i #{filename} -vn -acodec copy #{aac}")
            raise "failed to extract audio track."
          end
          puts "..finished"

          # faadへ渡して音声切り替えが起きているか検証する
          puts "validating audio track ...."
          system("#{DBEE::Config::FAAD} -w #{aac} >/dev/null 2>&1")
          puts "..finished"

          # FIXME: 異常終了か正常終了か見分けられない....
          if $?.exitstatus == 21
            # 切り替えあり
            puts "audio track varies channel settings. We need to split material."
            puts "Executing TsSplitter...."
            cmd = "wine #{DBEE::Config::TSSPLITTER} -SEPA -SD -1SEG -OUT #{dir} #{filename} >/dev/null 2>&1"
            unless system(cmd)
              raise "failed to execute TsSplitter.exe"
            end
            puts "..finished"
            # 複数の生成物からファイルサイズが一番大きいものを選ぶ
            new_material = Pathname.glob("#{dir}/*.ts").sort { |a, b|
              b.size <=> a.size
            }.first
            puts "rename #{filename} to #{filename}.orig"
            # まず以前のTSをリネーム
            filename.rename("#{filename}.orig.ts")
            # もとのファイル名にリネーム
            puts "rename #{new_material} to #{filename}"
            new_material.rename(filename)
          else
            # なし
          end
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
