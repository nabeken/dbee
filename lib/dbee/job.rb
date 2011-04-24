require 'dbee/job/encode/ipad'
require 'dbee/job/download'

module DBEE
  module Job
    attr_accessor :request_id, :request_url, :http

    # 個々のキーだけ更新するのか、リクエスト全体を更新するのか
    # valueがnilでなければ個々のキーを更新する
    def put_request(request, value = nil)
      unless value.nil?
        @http.put("#{@request_url}/#{request}", JSON.unparse({request => value}))
      else
        # リクエスト全体を更新する
        @http.put(@request_url, JSON.unparse(request))
      end
    end

    def get_request
      res = @http.get(@request_url)
      JSON.parse(res.content)
    end

    def delete_request(key)
      @http.delete("#{@request_url}/#{key}")
    end
  end
end
