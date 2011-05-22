#!/usr/bin/ruby
f = File.symlink?(__FILE__) ? File.dirname(File.readlink(__FILE__))
                            : File.dirname(__FILE__)
$LOAD_PATH.unshift f + '/../lib'
load f + '/../config.rb'

Encoding.default_external = "UTF-8" if defined? Encoding
Encoding.default_internal = "UTF-8" if defined? Encoding

require 'rack'
require 'pathname'
require 'uri'
require 'fileutils'
require 'dbee/digest'
require 'dbee/dav'

module DBEE
  class CGI
    class GenerateSHA256
      def call(env)
        request = Rack::Request.new(env)
        # 生成するファイル名取得
        target = Pathname.new(URI.decode(request[:target]))
        file = Pathname.new(DBEE::Config::DAV_DIR + '/' + target.basename.to_s)

        if file.exist?
          metadata = Pathname.new("#{DBEE::Config::DAV_DIR}/._dbee_metadata/" +
                                  "#{target.basename}.sha256")
          # PROPPATCHする
          dav = DAVAccess.new(DBEE::Config::HTTP_USER,
                              DBEE::Config::HTTP_PASSWORD)
          dav.propset(target.basename.to_s, "SHA256", FileDigest::SHA256.digest(file).hexdigest)
          [200, {}, []]
        else
          [404, {}, []]
        end
      end
    end
  end
end

Rack::Handler::CGI.run(DBEE::CGI::GenerateSHA256.new)
# vim:filetype=ruby
