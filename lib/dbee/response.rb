# coding:utf-8

# APIからのレスポンストを抽象化

module DBEE
  class Response
    attr_reader :http_response, :request_id

    # HTTPClientのresponse
    def initialize(response)
      @http_response = response
      # request_idはLocationヘッダかcontentから取り出す
      if response.headers["Location"].nil?
        @request_id = JSON.parse(response.content)["request_id"]
      else
        @request_id = response.headers["Location"].split('/').last
      end
    end

    def status
      @http_response.status
    end

    def body
      JSON.parse(@http_response.content)
    end

    def headers
      @http_response.headers
    end

    def url
      "#{DBEE::Config::API_URL}/request/#{@request_id}"
    end
  end
end
