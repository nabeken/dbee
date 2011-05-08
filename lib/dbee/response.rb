# vim:fileencoding=utf-8

# APIからのレスポンストを抽象化

module DBEE
  class Response
    attr_reader :http_response, :request_id

    # HTTPClientのresponse
    def initialize(response)
      @http_response = response
      @request_id = headers["Location"].split('/').last
    end

    def status
      @http_response.status
    end

    def body
      @http_response.body
    end

    def headers
      @http_response.headers
    end

    def url
      "#{DBEE::Config::API_URL}/request/#{@request_id}"
    end
  end
end
