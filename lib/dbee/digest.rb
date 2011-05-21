require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'

module DBEE
  class FileDigest
    def self.digest_from_file(digest, filename)
      File.open(filename, 'r') do |f|
        buf = ''
        while f.read(1024 * 8, buf)
          digest << buf
        end
      end
      digest
    end

    class SHA256
      def self.digest(filename)
        digest = Digest::SHA256.new
        FileDigest.digest_from_file(digest, filename)
      end
    end

    class MD5
      def self.digest(filename)
        digest = Digest::MD5.new
        FileDigest.digest_from_file(digest, filename)
      end
    end
  end
end
