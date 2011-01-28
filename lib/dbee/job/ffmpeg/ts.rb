require 'resque'

module DBEE
  module FFMPEG
    module TS
      module MASTER
        def perform(source, program_id)
          puts "start encoding..."
          ffmpeg_args = %w(-y -i)
          ffmpeg_args.push source
          ffmpeg_args += %w{
            -f mp4
            -vcodec h264
            -vpre ./libx264-hq.ffpreset
            -sameq
            -s 848x480
            -bufsize 20000k
            -maxrate 2500k
            -acodec aac
            -ar 48000
            -ac 2
            -ab 128k
            -vsync 1
            -programid 23608
            -threads 1
          }
          ffmpeg_args.push File.basename(source, '.ts') + '.m4v'
          unless system("ffmpeg", *ffmpeg_args)
            raise "ffmpeg failed to encoding, args: #{ffmpeg_args.join(" ")}"
          end
          puts "encoding sucessfully finished."
        end
      end

      module IS01
        def perform(source, program_id)
          puts "start encoding..."
          ffmpeg_args = %w(-y -i)
          ffmpeg_args.push source
          ffmpeg_args += %w{
            -f mp4
            -vcodec h264
            -vpre ./libx264-hq.ffpreset
            -sameq
            -s 848x480
            -bufsize 20000k
            -maxrate 2500k
            -acodec aac
            -ar 48000
            -ac 2
            -ab 128k
            -vsync 1
            -programid 23608
            -threads 1
          }
          ffmpeg_args.push File.basename(source, '.ts') + '.m4v'
          unless system("ffmpeg", *ffmpeg_args)
            raise "ffmpeg failed to encoding, args: #{ffmpeg_args.join(" ")}"
          end
          puts "encoding sucessfully finished."
        end
      end
    end
  end
end
