# vim:fileencoding=utf-8

require File.dirname(__FILE__) + '/spec_helper'
require 'dbee/app/request'

describe 'DBEE Request API App' do
  before(:all) do
    @posted_data = {:requests => []}
    @app = DBEE::App::Request
    # 成功したリクエストIDを保存して後のテストで使う
    @successed_request = {}
    @json_data = {
      "requester" => "shiho-dev.dev",
      "run_list" => [
        {
          "name" => "DBEE::Job::Download",
          "args" => {
            "base_url" => "http://example.org/"
          }
        },
        {
          "name" => "DBEE::Job::Encode::IPAD",
          "args" => {}
        }
      ],
      "program" => {
        "name"          => "まどか",
        "ch"            => "TBS",
        "filename"      => "magica_madoka.ts",
      }
    }

    initialize_redis
  end

  def initialize_redis
    Resque.redis.hkeys("request").each do |k|
      Resque.redis.hdel("request", k)
    end
    Resque.redis.del("request_id")
  end

  def initialize_posted_request(data, request_id)
    # 素材のメタデータ生成ジョブを追加
    run_list = [
      {
        "name"   => "DBEE::Job::GenerateMetadata",
        "args"   => {},
      }
    ]
    data["run_list"] = run_list + data["run_list"]
    # POST時にoutputを初期化し、request_idが振られる
    data["run_list"].each do |j|
      j["output"] = {}
    end
    data["request_id"] = request_id.to_i
  end

  it "posts valid JSON and gets same json" do
    data = @json_data.dup
    post '/', data.to_json
    last_response.status.should == 303
    request_id = last_response.headers["Location"].split('/').last
    initialize_posted_request(data, request_id)

    get "/#{request_id}"
    @successed_request[:request_id] = request_id
    @successed_request[:json] = last_response.body
    @posted_data[:requests].push JSON.parse(last_response.body)
    last_response.should be_ok
    JSON.parse(last_response.body).should == JSON.parse(data.to_json)
  end

  it "puts JSON using request id and gets updated json" do
    data = @json_data.dup
    post '/', data.to_json
    last_response.status.should == 303
    request_id = last_response.headers["Location"].split('/').last
    initialize_posted_request(data, request_id)

    data["requester"] = "rika.tokyo.tknetworks.org"
    data["program"]["name"] = "まどか☆マギカ"

    put "/#{request_id}", data.to_json
    @posted_data[:requests].push JSON.parse(last_response.body)
    last_response.should be_ok
    JSON.parse(last_response.body).should == JSON.parse(data.to_json)
  end

  it "gets two request's array" do
    get '/'
    last_response.should be_ok
    JSON.parse(last_response.body).should == JSON.parse(@posted_data.to_json)
  end

  it "says request not found" do
    get '/33333333'
    last_response.status.should == 404
  end

  it "posts invalid JSON and gets error" do
    post '/', "aaa"
    last_response.status.should == 400
  end

  it "posts insufficient JSON and gets error" do
    post '/', {
      "aaa" => "bbb"
    }.to_json
    last_response.status.should == 400
  end


  it "gets successed request JSON using request id" do
    get "/#{@successed_request[:request_id]}"
    last_response.should be_ok
    JSON.parse(last_response.body).should == JSON.parse(@successed_request[:json])
  end

  it "puts invalid JSON using request id" do
    put "/#{@successed_request[:request_id]}", "aaaa"
    last_response.status.should == 400
  end

  it "puts insufficient JSON using request id" do
    put "/#{@successed_request[:request_id]}", {"requester" => "shiho.tokyo"}.to_json
    last_response.status.should == 400
  end

  it "puts requester using request id and get only updated requester json" do
    get "/#{@successed_request[:request_id]}"
    last_response.should be_ok

    orig_data = last_response.body.dup

    data = JSON.parse(orig_data)
    data["requester"] = "madoka-san.tokyo.tknetworks.org"
    data["worker"] = "mami.tokyo.tknetworks.org"

    data2 = JSON.parse(orig_data)
    data2["requester"] = "madoka-san.tokyo.tknetworks.org"

    put "/#{@successed_request[:request_id]}/requester", data.to_json
    @successed_request[:json] = last_response.body

    # dataでrequesterをworkerを更新したが、requesterをPUTしたのでrequesterだけ更新される
    last_response.should be_ok
    JSON.parse(last_response.body).should == JSON.parse(data2.to_json)
  end

  it "gets requester using request id" do
    data = JSON.parse(@successed_request[:json])
    get "/#{@successed_request[:request_id]}/requester"
    JSON.parse(last_response.body).should == JSON.parse({"requester" => data["requester"]}.to_json)
  end

  it "puts invalid requester using request id" do
    put "/#{@successed_request[:request_id]}/requester", "shiho.tokyo.tknetworks.org"
    last_response.status.should == 400
  end

  it "puts requester not including requester and gets error" do
    put "/#{@successed_request[:request_id]}/requester",
        {"program" => "shiho.tokyo.tknetworks.org"}.to_json
    last_response.status.should == 400
  end

  it "puts successed request's running_job using request id" do
    get "/#{@successed_request[:request_id]}"
    last_response.should be_ok
    orig_data = last_response.body.dup

    data = JSON.parse(orig_data)
    data["running_job"] = "DBEE::Job::Encode::IPAD"
    @successed_request[:running_job] = "DBEE::Job::Encode::IPAD"
    data["worker"] = "hogemoge.tokyo"

    data2 = JSON.parse(orig_data)
    data2["running_job"] = "DBEE::Job::Encode::IPAD"

    put "/#{@successed_request[:request_id]}/running_job", data.to_json
    last_response.should be_ok
    JSON.parse(last_response.body).should == JSON.parse(data2.to_json)
  end

  it "gets successed request's running_job using request id" do
    get "/#{@successed_request[:request_id]}/running_job"
    last_response.should be_ok
    JSON.parse(
      {"running_job" => @successed_request[:running_job]}.to_json
    ).should == JSON.parse(last_response.body)
  end

  it "puts successed request's running_job using invalid json" do
    put "/#{@successed_request[:request_id]}/running_job", "aaaa"
    last_response.status.should == 400
  end

  it "puts successed request's running_job using insufficient json" do
    put "/#{@successed_request[:request_id]}/running_job",
        {"requester" => "shiho.tokyo"}.to_json
    last_response.status.should == 400
  end

  it "deletes successed request's running_job using request it" do
    delete "/#{@successed_request[:request_id]}/running_job"
    last_response.status.should == 303
    get "/#{@successed_request[:request_id]}"
    JSON.parse(last_response.body).should_not be_has_key("running_job")

    delete "/#{@successed_request[:request_id]}/running_job"
    last_response.status.should == 404
  end

  it "deletes successed request's running_job which has next_same_node = true" do
    data = @json_data.dup
    post '/', data.to_json
    last_response.status.should == 303
    request_id = last_response.headers["Location"].split('/').last

    get "/#{request_id}"
    data2 = JSON.parse(last_response.body)
    data2["worker"] = "shiho-dev.tokyo.tknetworks.org"
    data2["running_job"] = "DBEE::Job::Download"
    data2["run_list"][0]["output"]["next_same_node"] = true
    data2["run_list"].push({
      "name" => "DBEE::Job::Download",
      "args" => {
        "url"    => "http://example.org/hoge.ts",
        "output" => true
      }
    })
    put "/#{request_id}", data2.to_json
    last_response.should be_ok

    delete "/#{request_id}/running_job"
    last_response.status.should == 303
  end
end
