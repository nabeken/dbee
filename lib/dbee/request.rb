# vim:fileencoding=utf-8

# FIXME: Transfer-Encoding: chunkedを使わないバージョンが取り込まれたら消す
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../vendor/httpclient/lib'

require 'httpclient'
require 'dbee/response'

# APIへのリクエストを抽象化
module DBEE
  class Request
    attr_accessor :request_id
    attr_reader :http

    def initialize(request_id = nil)
      @request_id = request_id
      @http = Request.get_new_http_client
    end

    def get
      response = @http.get("#{Request.request_url}/#{@request_id}")
      if response.status != 200
        raise "failed to GET request##{@request_id}. got #{response.status}"
      end
      Response.new(response)
    end

    # 個々のキーだけ更新するのか、リクエスト全体を更新するのか
    # valueがnilでなければ個々のキーを更新する
    def put(request, value = nil)
      unless value.nil?
        response = @http.put("#{Request.request_url}/#{@request_id}/#{request}", JSON.unparse({request => value}))
      else
        # リクエスト全体を更新する
        response = @http.put("#{Request.request_url}/#{@request_id}", JSON.unparse(request))
      end
      if response.status != 200
        raise "failed to PUT request##{@request_id}. got #{response.status}"
      end
      Response.new(response)
    end

    def delete(key)
      response = @http.delete("#{Request.request_url}/#{@request_id}/#{key}")
      if response.status != 200 and response.status != 303
        raise "failed to DELETE request##{@request_id}. got #{response.status}"
      end
      Response.new(response)
    end

    def start_job(args)
      put("running_job", args[:running_job])
      put("worker", args[:worker])
    end

    # POST時はまだrequest_idがないため特異メソッドとして用意し、
    # 戻り値としてResponseのインスタンスを返す
    class << self
      def post(request)
        http = get_new_http_client
        response = http.post("#{Request.request_url}", request)
        # 成功時は303 see otherが返る
        if response.status != 303
          raise "failed to POST request. got #{response.status}"
        end
        Response.new(response)
      end

      def get_new_http_client(user = nil, pass = nil)
        user ||= DBEE::Config::HTTP_USER
        pass ||= DBEE::Config::HTTP_PASSWORD
        proxy = ENV['HTTP_PROXY'] || ENV['http_proxy'] || nil
        http = HTTPClient.new(proxy)
        http.set_auth('/', user, pass)
        http.ssl_config.add_trust_ca(DBEE::Config::CA_DIR)
        http.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http
      end

      def get(url, &block)
        http = Request.get_new_http_client
        http.set_auth(url, DBEE::Config::HTTP_USER, DBEE::Config::HTTP_PASSWORD)
        if block.nil?
          http.get(url)
        else
          http.get(url, :follow_redirect => true) do |data|
            block.call(data)
          end
        end
      end

      def request_url
        "#{DBEE::Config::API_URL}/request"
      end
    end
  end
end
