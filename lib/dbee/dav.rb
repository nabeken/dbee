# vim:fileencoding=utf-8

require 'dbee/request'
require 'httpclient'
require 'nokogiri'

# WebDAVへのアクセスを抽象化
module DBEE
  class DAVAccess
    attr_accessor :http_user, :http_password
    def initialize(user, pass)
      @http_user = user
      @http_password = pass
      @http = Request.get_new_http_client(@http_user,
                                          @http_password,
                                          DBEE::Config::Upload::DAV_STORAGE_BASE_URL)
      # WORKAROUND: Set send_timeout, receive_timeout to 1 days
      @http.send_timeout = 86400
      @http.receive_timeout = 85400
    end

    def put(key, f)
      raise "content must be file" unless HTTP::Message.file?(f)
      full_url = get_full_url(key)
      base_url = "#{DBEE::Config::Upload::DAV_STORAGE_BASE_URL}#{File.dirname(full_url.path)}"
      # ディレクトリがなければ作成
      response = @http.get(base_url)
      if response.status == 404
        unless @http.request(:mkcol, base_url).status == 201
          raise "failed to create collection #{base_url}"
        end
      end
      # PUTを発行
      response = @http.put(full_url, :body => f)
      if response.status != 200 and response.status != 204 and response.status != 201
        raise "failed to put #{File.basename(f)}, status: #{response.status}"
      end
      # ハッシュ値生成用CGIをkick
      response = @http.get(
        "#{DBEE::Config::Upload::DAV_STORAGE_BASE_URL}/cgi-bin/dbee-generate-sha256.cgi",
        :target => key
      )
      if response.status != 200
        raise "failed to generate SHA256, status: #{response.inspect}"
      end
    end

    def get(key)
      # TODO: GETを発行
    end

    def propget(key, name)
      full_url = get_full_url(key)
      header = get_header
      response = @http.request(:propfind, full_url, :body   => propfind_xml(name),
                                                    :header => header)
      if response.status != 207
        raise "failed to PROPFIND #{key}, status #{response.status}"
      end
      status, multi_status = get_multi_status(response.content)
      if status != 200
        raise "failed to propget #{status}"
      end
      multi_status.css("ns1|#{name}").text
    end

    def propset(key, name, value)
      full_url = get_full_url(key)
      header = get_header
      header['Depth'] = 0
      response = @http.request(:proppatch, full_url,
                               :body => proppatch_xml(name, value),
                               :header => header)
      if response.status != 207
        raise "failed to PROPSET. status: #{response.status}"
      end
      STDERR.puts response.content if $DEBUG
      status = get_multi_status(response.content).first
      if status != 200
        raise "failed to proppatch #{status}"
      end
    end

    def get_multi_status(response)
      multi_status = Nokogiri::XML(response)
      [multi_status.css("D|status").first.text.split(' ', 3)[1].to_i, multi_status]
    end

    def get_full_url(key)
      URI.parse("#{DBEE::Config::Upload::DAV_STORAGE_BASE_URL}/#{URI.encode(key)}")
    end

    def get_header
      {
        'Content-Type' => 'application/xml',
        'User-Agent'   => 'DbeE'
      }
    end

    def propfind_xml(key)
    xml = <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <#{key} xmlns="http://webdav.org/cadaver/custom-properties/"/>
  </prop>
</propfind>
EOF
    end

    def proppatch_xml(key, value)
    xml = <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<D:propertyupdate xmlns:D="DAV:">
  <D:set>
    <D:prop>
      <#{key} xmlns="http://webdav.org/cadaver/custom-properties/">#{value}</#{key}>
    </D:prop>
  </D:set>
</D:propertyupdate>
EOF
    end
  end
end
