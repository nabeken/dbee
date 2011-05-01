require 'dbee/job/encode/ipad'
require 'dbee/job/download'
require 'dbee/job/generate_metadata'
require 'dbee/job/upload/s3'
require 'dbee/job/notification'

Encoding.default_internal = "UTF-8" if defined? Encoding
Encoding.default_external = "UTF-8" if defined? Encoding

module DBEE
  module Job
    # 個々のキーだけ更新するのか、リクエスト全体を更新するのか
    # valueがnilでなければ個々のキーを更新する
    def put_request(request, value = nil)
      unless value.nil?
        response = @http.put("#{@request_url}/#{request}", JSON.unparse({request => value}))
      else
        # リクエスト全体を更新する
        response = @http.put(@request_url, JSON.unparse(request))
      end

      if response.status != 200
        raise "failed to PUT request##{@request_id}. got #{response.status}"
      end
    end

    def get_request
      response = @http.get(@request_url)
      if response.status != 200
        raise "failed to GET request##{@request_id}. got #{response.status}"
      end
      JSON.parse(response.content)
    end

    def delete_request(key)
      response = @http.delete("#{@request_url}/#{key}")
      if response.status != 200 and response.status != 303
        raise "failed to DELETE request##{@request_id}. got #{response.status}"
      end
    end
  end
end
