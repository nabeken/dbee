require 'resque'
require 'digest/sha1'

module DBEE
  module FFMPEG
    module TS
      module MASTER
        def perform(source)
          puts "start encoding..."
          ffmpeg_args = %w(-y -i)
          ffmpeg_args.push source
          ffmpeg_args += %w{
            -f mp4
            -vcodec libx264
            -fpre
          }
          ffmpeg_args.push DBEE::FFMPEG::FPRE
          ffmpeg_args += %w{
            -sameq
            -s 1440x1080
            -bufsize 20000k
            -maxrate 15000k
            -acodec libfaac
            -ar 48000
            -ac 2
            -ab 128k
            -vsync 1
            -threads 1
          }
          output = "#{DBEE::FFMPEG::SAVE_DIR}/" + File.basename(source, '.ts') + '-' + Digest::SHA1.hexdigest(Time.now.to_f.to_s) + '.m4v'
          ffmpeg_args.push output
          unless system("ffmpeg", *ffmpeg_args)
            raise "ffmpeg failed to encoding, args: #{ffmpeg_args.join(" ")}"
          end
          puts "encoding sucessfully finished. Saved to #{output}"
        end
      end

      module IS01
        def perform(source)
          puts "start encoding..."
          ffmpeg_args = %w(-y -i)
          ffmpeg_args.push source
          ffmpeg_args += %w{
            -f mp4
            -vcodec libx264
            -fpre
          }
          ffmpeg_args.push DBEE::FFMPEG::FPRE
          ffmpeg_args += %w{
            -sameq
            -s 848x480
            -bufsize 20000k
            -maxrate 2500k
            -acodec libfaac
            -ar 48000
            -ac 2
            -ab 128k
            -vsync 1
            -threads 2
          }
          output = "#{DBEE::FFMPEG::SAVE_DIR}/" + File.basename(source, '.ts') + '-' + Digest::SHA1.hexdigest(Time.now.to_f.to_s) + '.m4v'
          ffmpeg_args.push output
          unless system("ffmpeg", *ffmpeg_args)
            raise "ffmpeg failed to encoding, args: #{ffmpeg_args.join(" ")}"
          end
          puts "encoding sucessfully finished. Saved to #{output}"
        end
      end
    end
  end
end
