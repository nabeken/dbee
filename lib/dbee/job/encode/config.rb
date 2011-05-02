require 'facter'
require 'fileutils'

# initialize facter
Facter.to_hash

module DBEE
  module Job
    module Encode
      class Config
        attr_accessor :source, :size, :dir, :program_id
        attr_reader :output

        def initialize
          @dir = "default"
          @program_id = ""
        end

        def get_cmd
            ffmpeg_args =  " -y -i \"#{@source}\""
            ffmpeg_args << " -f mp4 -vcodec libx264"
            ffmpeg_args << " -fpre #{DBEE::Config::Encode::PRESET} -sameq"
            ffmpeg_args << " -s #{@size}"
            ffmpeg_args << " -aspect 16:9"
            ffmpeg_args << " -bufsize 1400k -maxrate 12000k -acodec libfaac"
            ffmpeg_args << " -ar 48000 -ac 2 -ab 128k -vsync 1"

            if Facter.kernel == "FreeBSD"
              processorcount = `sysctl -n hw.ncpu`.strip
            else
              processorcount = Facter.processorcount
            end
            ffmpeg_args << " -threads #{processorcount}"

            unless @program_id.empty?
              ffmpeg_args << " -programid #{@program_id}"
            end

            # 一時ファイルへ保存する
            save_dir = "#{DBEE::Config::Encode::OUTPUT_DIR}/#{@dir}/"
            FileUtils.mkdir_p(save_dir) unless File.exists?(save_dir)

            @output = save_dir + File.basename(source, '.ts') + '.m4v'
            ffmpeg_args << " \"#{@output}\""
            ffmpeg_args
          end

          def set_programid
            @program_id = DBEE::Config::Encode::PROGRAM_ID.find { |key, val| key.match(@source) }
            # 何もマッチしなかった場合はデフォルトへfallback
            if @program_id.nil?
              @program_id = ""
            else 
              @program_id.last
            end
          end
      end
    end
  end
end
