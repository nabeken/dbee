require 'sinatra/base'
require 'resque'
require 'json'
require 'dbee/job'

module DBEE
  class App
    class Request < Sinatra::Base
      helpers do
        def issue_new_request_id
          Resque.redis.incr("request_id")
        end

        def validate_request(json_request, keys)
          keys.all? do |k|
            json_request.has_key?(k)
          end
        end

        def get_class_name(classname)
          classname.split("::").inject(Kernel) { |scope, const_name|
            scope.const_get(const_name)
          }
        end
      end

      # all request are mounted on /request
      get '/' do
        "test"
      end

      post '/' do
        # POSTされたJSONを取得
        request.body.rewind

        begin
          dbee_request = JSON.parse(request.body.read)
        rescue
          halt 400, "Invalid JSON passed\n"
        end

        # 全要素が揃っているか確認
        unless validate_request(dbee_request, %w(requester run_list program))
          # 要素が揃っていないのでacceptしない
          halt 400, "Request at least needs 'requester', 'run_list', 'program' params\n"
        end

        # run_list内のoutputを初期化する
        dbee_request["run_list"].each do |r|
          r["output"] = {}
        end

        # request_idを発行する
        request_id = issue_new_request_id
        dbee_request["request_id"] = request_id

        # run_listはここではまだ取り除かないので先にhsetしておく。
        # Redisへ永続化
        json = JSON.unparse(dbee_request)
        Resque.redis.hset("request", request_id, json)

        # run_listをshiftし次に実行するジョブ名を取得
        run_list = dbee_request["run_list"].shift
        next_job = get_class_name(run_list["name"])

        # エンキューする
        Resque.enqueue(next_job, request_id, run_list["name"], run_list["args"])

        # レスポンス生成
        # 303 See Other で redirect する
        content_type :json
        redirect "/request/#{request_id}", 303
      end

      put '/:id' do
        # JSONのキーすべてでリクエストを上書きする
        # PUTされたJSONを取得
        request.body.rewind
        begin
          dbee_request = JSON.parse(request.body.read)
        rescue
          halt 400, "Invalid JSON passed\n"
        end
        required_keys = %w(requester run_list program)
        unless validate_request(dbee_request, required_keys)
          halt 400, "Request at least need '#{required_keys.join(", ")}' parameter.\n"
        end
        requested = JSON.parse(Resque.redis.hget("request", params[:id]))
        dbee_request.keys.each do |k|
          requested[k] = dbee_request[k]
        end
        json = JSON.unparse(requested)
        content_type :json
        Resque.redis.hset("request", params[:id], json)
      end

      # return resources
      get '/:id' do
        # Redisから取得したJSONをそのまま返す
        if Resque.redis.hexists("request", params[:id])
          content_type :json
          Resque.redis.hget("request", params[:id])
        else
          halt 404, "Request ##{params[:id]} not found\n"
        end
      end

      %w(requester worker run_list ran_list program).each do |k|
        get "/:id/#{k}" do
          content_type :json
          requested = JSON.parse(Resque.redis.hget("request", params[:id]))
          requested[k].to_json
        end

        put "/:id/#{k}" do
          # PUTされたJSONを取得
          request.body.rewind
          # JSONのバリデート
          begin
            dbee_request = JSON.parse(request.body.read)
          rescue
            halt 400, "Invalid JSON passed\n"
          end

          unless validate_request(dbee_request, [k])
            halt 400, "Request at least need '#{k}' parameter.\n"
          end
          requested = JSON.parse(Resque.redis.hget("request", params[:id]))
          requested[k] = dbee_request[k]
          content_type :json
          Resque.redis.hset("request", params[:id], JSON.unparse(requested))
        end
      end

      get "/:id/running_job" do
        requested = JSON.parse(Resque.redis.hget("request", params[:id]))
        content_type :json
        requested[k].to_json
      end

      put "/:id/running_job" do
        # PUTされたJSONを取得
        request.body.rewind
        # JSONのバリデート
        begin
          dbee_request = JSON.parse(request.body.read)
        rescue
          halt 400, "Invalid JSON passed\n"
        end

        unless validate_request(dbee_request, %w(running_job))
          halt 400, "Request at least need running_job parameter.\n"
        end
        requested = JSON.parse(Resque.redis.hget("request", params[:id]))
        requested["running_job"] = dbee_request["running_job"]
        content_type :json
        Resque.redis.hset("request", params[:id], JSON.unparse(requested))
      end

      delete '/:id/running_job' do
        begin
          requested = JSON.parse(Resque.redis.hget("request", params[:id]))
          # DELETEをリクエストした時のrunning_job
          running_job = requested["running_job"]

          # キーがあれば削除
          if requested.has_key?("running_job")
            requested.delete("running_job")
            # 今のジョブ情報を取得する
            job = requested["run_list"].shift
            # ran_listへ移動
            if requested["ran_list"].nil?
              requested["ran_list"] = []
            end
            requested["ran_list"].push job

            # 次のジョブがあれば投入する
            unless requested["run_list"].empty?
              next_job = requested["run_list"].first
              next_job_class = get_class_name(next_job["name"])

              # 次のキューは今のジョブと同じノードにするかどうか
              if job["output"]["next_same_node"]
                next_job_class.instance_variable_set(
                  :@host_based_queue, requested["worker"].to_sym
                )
              end
              Resque.enqueue(next_job_class,
                             params[:id],
                             next_job["name"],
                             next_job["args"],
                             job["output"])
            end
            Resque.redis.hset("request", params[:id], JSON.unparse(requested))
            # レスポンス生成
            # 303 See Other で redirect する
            redirect "/request/#{params[:id]}", 303
          else
            # すでにないのに削除しようとすると404?405?
            halt 404
          end
        rescue
          halt 400, "Invalid JSON passed\n"
        end
      end
    end
  end
end
