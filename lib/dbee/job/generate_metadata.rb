# vim:fileencoding=utf-8

require 'dbee/digest'
require 'dbee/job'
require 'facter'
require 'fileutils'
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
        metadata_dir = filename.dirname + '._dbee_metadata'
        metadata_file = metadata_dir + "#{filename.basename}.json"

        unless File.exist?(filename)
          request_data["running_job"] = nil
          request.put(request_data)
          raise "material not found"
        end

        FileUtils.mkdir_p(metadata_dir) unless metadata_dir.exist?

        # すでにmetadataが生成済みならそのまま終了
        if File.exist?(metadata_file)
          puts "metadata for #{basename} found. skipped...."
        else
          # 一時ディレクトリを作る
          Dir.mktmpdir("dbee-") do |dir|
            aac = "#{dir}/#{filename.basename}.aac"
            # まずTSからAACだけ抜く
            puts "Extracting audio track from #{filename}...."
            cmd = "ffmpeg -i \"#{filename}\" -vn -acodec copy \"#{aac}\" >/dev/null 2>&1"
            unless system(cmd)
              raise "failed to extract audio track. #{cmd}. return code: #{$?}"
            end
            puts "..finished"

            # faadへ渡して音声切り替えが起きているか検証する
            puts "validating audio track ...."
            system("#{DBEE::Config::FAAD} -w \"#{aac}\" >/dev/null 2>&1")
            puts "..finished"

            # FIXME: 異常終了か正常終了か見分けられない....
            # FIXME: 21以外にも32の場合もあった
            if $?.exitstatus == 21 or $?.exitstatus == 32
              # 切り替えあり
              puts "audio track varies channel settings. We need to split material."
              puts "Executing TsSplitter...."
              cmd = "LANG=ja_JP.UTF-8 #{DBEE::Config::WINE} #{DBEE::Config::TSSPLITTER} -SEPA -SD -1SEG -OUT #{dir} \"#{filename}\" >/dev/null 2>&1"
              unless system(cmd)
                raise "failed to execute TsSplitter.exe"
              end
              puts "..finished"
              # 複数の生成物からファイルサイズが一番大きいものを選ぶ
              new_material = Pathname.glob("#{dir}/*.ts").sort { |a, b|
                b.size <=> a.size
              }.first
              if new_material.nil?
                raise "execute TsSplitter failed"
              end
              puts "rename #{filename} to #{filename}.orig"
              # まず以前のTSをリネーム
              filename.rename("#{filename}.orig.ts")
              # もとのファイル名へ移動
              puts "rename #{new_material} to #{filename}"
              FileUtils.mv(new_material, filename)
            else
              # なし
            end
          end

          puts "Calculating SHA256 for #{basename}...."
          digest = FileDigest::SHA256.digest(filename)

          # JSONの生成
          json = {
            "filename" => basename,
            "size"     => filename.size,
            "SHA256"   => digest.hexdigest,
            "mtime"    => filename.mtime,
            "ctime"    => filename.ctime,
          }

          File.open(metadata_file, 'w') do |f|
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
