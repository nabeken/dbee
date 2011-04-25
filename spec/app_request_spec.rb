# vim:fileencoding=utf-8

require File.dirname(__FILE__) + '/spec_helper'
require 'dbee/app/request'

describe 'DBEE Requedt API App' do
  before(:all) do
    @app = DBEE::App::Request
    # 成功したリクエストIDを保存して後のテストで使う
    @successed_request = {}
    @json_data = {
      "requester" => "shiho-dev.dev",
      "run_list" => [
        {
          "name" => "DBEE::Job::Download",
          "args" => {
            "url" => "http://example.org/hoge.ts"
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
        "checksum.SHA1" => "aaaa"
      }
    }
  end

  def initialize_posted_request(data, request_id)
    # POST時にoutputを初期化し、request_idが振られる
    data["run_list"].each do |j|
      j["output"] = {}
    end
    data["request_id"] = request_id.to_i
  end


  it "says test" do
    get '/'
    last_response.should be_ok
    last_response.body.should == "test"
  end

  it "says request not found" do
    get '/33333333'
    last_response.status.should == 404
  end

  it "posts invalid JSON and gets error" do
    post '/', {
      "aaa" => "bbb"
    }.to_json
    last_response.status.should == 400
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
    last_response.should be_ok
    JSON.parse(last_response.body).should == JSON.parse(data.to_json)
  end

  it "puts JSON using request id and gets updated json" do
    data = @json_data.dup
    post '/', data.to_json
    last_response.status.should == 303
    request_id = last_response.headers["Location"].split('/').last

    data["requester"] = "rika.tokyo.tknetworks.org"
    data["program"]["name"] = "まどか☆マギカ"

    put "/#{request_id}", data.to_json

    initialize_posted_request(data, request_id)

    last_response.should be_ok
    JSON.parse(last_response.body).should == JSON.parse(data.to_json)
  end

  it "gets successed request JSON using request id" do
    get "/#{@successed_request[:request_id]}"
    last_response.should be_ok
    JSON.parse(last_response.body).should == JSON.parse(@successed_request[:json])
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

  it "deletes successed request's running_job using request it" do
    delete "/#{@successed_request[:request_id]}/running_job"
    last_response.status.should == 303
    get "/#{@successed_request[:request_id]}"
    JSON.parse(last_response.body).should_not be_has_key("running_job")

    delete "/#{@successed_request[:request_id]}/running_job"
    last_response.status.should == 404
  end
end
