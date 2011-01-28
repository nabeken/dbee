require 'dbee/job/ffmpeg/ts'

module DBEE
  module ANIME
    module MASTER
      class NEW
        @queue = :new_anime_master
        extend FFMPEG::TS::MASTER
      end
    end

    module IS01
      @queue = :new_anime_portable
      extend FFMPEG::TS::IS01
    end
  end
end
