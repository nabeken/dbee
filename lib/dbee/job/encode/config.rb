# coding:utf-8

require 'facter'
require 'fileutils'

# initialize facter
Facter.to_hash

module DBEE
  module Job
    module Encode
      class Config
        attr_accessor :source, :size, :dir, :save_dir
        attr_reader :output

        def initialize
          @dir = "default"
          @program_id = ""
          @cmd_format = "-y -i \"%s\" -f mp4 -vcodec libx264 -vsync 1 " +
                        "-fpre %s -r 30000/1001 -s %s -aspect 16:9 " +
                        "-bufsize 14000k -maxrate 2500k -acodec libfaac " +
                        "-ar 48000 -ac 2 -ab 128k -async 1 -threads %s"
        end

        def get_processor_count
          if Facter.kernel == "FreeBSD"
            processorcount = `sysctl -n hw.ncpu`.strip
          else
            processorcount = Facter.processorcount
          end
          processorcount
        end

        def get_programid
          program_id = DBEE::Config::Encode::PROGRAM_ID.find { |key, val| key.match(@source) }
          # 何もマッチしなかった場合はデフォルトへfallback
          program_id.nil? ? nil : program_id.last
        end

        def output
          "#{save_dir}#{File.basename(source, '.ts')}.m4v"
        end

        def save_dir
          "#{DBEE::Config::Encode::OUTPUT_DIR}/#{dir}/"
        end

        def mk_save_dir
          FileUtils.mkdir_p(save_dir) unless File.exist?(save_dir)
        end

        def get_cmd
          format_args = [@source, DBEE::Config::Encode::PRESET, @size, get_processor_count]

          unless get_programid.nil?
            @cmd_format << " -programid %s"
            format_args.push(get_programid)
          end

          @cmd_format % format_args
        end

      end
    end
  end
end
