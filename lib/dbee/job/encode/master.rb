require 'dbee/job/encode/config'

module DBEE
  module Job
    module Encode
      class Master
        def perform(source)
          puts "start encoding..."
          config = FFMPEG::Config.new
          config.source = source
          config.size = "1440x1080"
          config.dir = "master"
          config.set_programid
          puts "PROGRAM_ID: #{config.program_id}"
          unless system("ffmpeg" + config.get_cmd)
            raise "ffmpeg failed to encoding, args: #{config.getCmd}"
          end
          puts "encoding sucessfully finished. Saved to #{config.output}"
        end
      end
    end
  end
end
