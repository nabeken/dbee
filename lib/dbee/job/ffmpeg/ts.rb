require 'resque'
require 'digest/sha1'
require 'facter'
require 'fileutils'

# initialize facter
Facter.to_hash

module DBEE
  module FFMPEG
    class Config
      attr_accessor :source, :size, :dir
      attr_reader :output

      def initialize
        @dir = "default"
      end

      def getCmd
          ffmpeg_args =  " -y -i \"#{@source}\""
          ffmpeg_args << " -f mp4 -vcodec libx264"
          ffmpeg_args << " -fpre #{DBEE::FFMPEG::PRESET} -sameq"
          ffmpeg_args << " -s #{@size}"
          ffmpeg_args << " -aspect 16:9"
          ffmpeg_args << " -bufsize 20000k -maxrate 15000k -acodec libfaac"
          ffmpeg_args << " -ar 48000 -ac 2 -ab 128k -vsync 1"

          if Facter.kernel == "FreeBSD"
            processorcount = `sysctl -n hw.ncpu`.strip
          else
            processorcount = Facter.processorcount
          end

          ffmpeg_args << " -threads #{processorcount}"

          save_dir = "#{DBEE::FFMPEG::SAVE_DIR}/#{@dir}/"
          FileUtils.mkdir_p(save_dir) unless File.exists?(save_dir)
          @output   = save_dir + File.basename(source, '.ts') + '.m4v'
          ffmpeg_args << " \"#{@output}\""
          ffmpeg_args
        end
    end

    module TS
      module MASTER
        def perform(source)
          puts "start encoding..."
          config = FFMPEG::Config.new
          config.source = source
          config.size = "1440x1080"
          config.dir = "master"
          unless system("ffmpeg" + config.getCmd)
            raise "ffmpeg failed to encoding, args: #{config.getCmd}"
          end
          puts "encoding sucessfully finished. Saved to #{config.output}"
        end
      end

      module IS01
        def perform(source)
          puts "start encoding..."
          config = FFMPEG::Config.new
          config.source = source
          config.size = "848x480"
          config.dir = "IS01"
          unless system("ffmpeg" + config.getCmd)
            raise "ffmpeg failed to encoding, args: #{config.getCmd}"
          end
          puts "encoding sucessfully finished. Saved to #{config.output}"
        end
      end
    end
  end
end
