require 'resque'
require 'digest/sha1'
require 'facter'

# initialize facter
Facter.to_hash

module DBEE
  module FFMPEG
    class Config
      attr_accessor :source, :size
      attr_reader :output

      def getCmd
          ffmpeg_args =  " -y -i \"#{@source}\""
          ffmpeg_args << " -f mp4 -vcodec libx264"
          ffmpeg_args << " -fpre #{DBEE::FFMPEG::PRESET} -sameq"
          ffmpeg_args << " -s #{@size}"
          ffmpeg_args << " -bufsize 20000k -maxrate 15000k -acodec libfaac"
          ffmpeg_args << " -ar 48000 -ac 2 -ab 128k -vsync 1"
          ffmpeg_args << " -threads #{Facter.value('ProcessorCount')}"

          @output = "#{DBEE::FFMPEG::SAVE_DIR}/" + File.basename(source, '.ts') + '-' + Digest::SHA1.hexdigest(Time.now.to_f.to_s) + '.m4v'

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
          unless system("ffmpeg" + config.getCmd)
            raise "ffmpeg failed to encoding, args: #{config.getCmd}"
          end
          puts "encoding sucessfully finished. Saved to #{config.output}"
        end
      end
    end
  end
end
