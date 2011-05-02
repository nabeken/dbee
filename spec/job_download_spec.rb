# vim:fileencoding=utf-8

require File.dirname(__FILE__) + '/spec_helper'
require 'dbee/app/request'
require 'dbee/job/download'
require 'dbee/job'
require 'digest/sha2'

describe 'DBEE Download Job' do
  before(:all) do
    @original_file = Pathname.new(File.dirname(__FILE__) + '/../coverage/assets/0.4.4/favicon.png')
    @download_dir = "#{DBEE::Config::Encode::OUTPUT_DIR}/download"
    # 成功したリクエストIDを保存して後のテストで使う
    @successed_request = {}
    @json_download_job = {
      "requester"   => "rspec.tokyo",
      "running_job" => "DBEE::Job::Download",
      "request_id" => "1",
      "run_list" => [
        {
          "name" => "DBEE::Job::Download",
          "args" => {
            "base_url" => "http://192.168.5.3:9393/coverage/assets/0.4.4/"
          },
          "output" => {}
        }
      ],
      "program" => {
        "name"          => "まどか",
        "ch"            => "TBS",
        "filename"      => "favicon.png"
      }
    }

    # jsonの生成
    digest = Digest::SHA256.hexdigest(File.open(@original_file).read)
    output = {
      "filename" => @original_file.basename,
      "size"     => @original_file.size,
      "SHA256"   => digest,
      "mtime"    => @original_file.mtime,
      "ctime"    => @original_file.ctime
    }
    File.open("#{@original_file}.json", "w") do |f|
      f.puts output.to_json
    end
  end

  it "performs downloading successfully" do
    # まずリクエストをJSONにして直接Redisへ入れる
    request_id  = @json_download_job["request_id"]
    running_job = @json_download_job["running_job"]
    args        = @json_download_job["run_list"][0]["args"]
    output      = @json_download_job["run_list"][0]["output"]

    Resque.redis.hset("request", request_id, @json_download_job.to_json)
    proc {
      DBEE::Job::Download.perform(request_id, running_job, args, output)
    }.should_not raise_error

    Digest::SHA1.hexdigest(File.open(@original_file).read).should == Digest::SHA1.hexdigest(
      File.open(@download_dir + "/#{@json_download_job["program"]["filename"]}").read
    )
  end

  it "performs downloading file does not exists" do
    request = @json_download_job.dup
    request["run_list"][0]["args"]["base_url"] = "http://192.168.5.3:9393/coverage/"
    request["program"]["filename"] = "notfound.jpeg"
    request_id  = request["request_id"]
    running_job = request["running_job"]
    args        = request["run_list"][0]["args"]
    output      = request["run_list"][0]["output"]
    Resque.redis.hset("request", request_id, request.to_json)
    proc {
      DBEE::Job::Download.perform(request_id, running_job, args, output)
    }.should raise_error

    File.exists?(@download_dir + "/#{request["program"]["filename"]}").should be_false
  end

  it "performs downloading w/ invalid request id" do
    proc {
      DBEE::Job::Download.perform("12345", "DBEE::Job::Download", {}, {})
    }.should raise_error
  end

  it "performs downloading w/ metadata available, material does not exists" do
    request = @json_download_job.dup
    request["run_list"][0]["args"]["base_url"] = "http://192.168.5.3:9393/coverage/assets/0.4.4/"
    request["program"]["filename"] = "favicon.png"
    request_id  = request["request_id"]
    running_job = request["running_job"]
    args        = request["run_list"][0]["args"]
    output      = request["run_list"][0]["output"]

    # favicon.pngを保存して一旦削除
    favicon = File.open(@original_file).read
    File.unlink(@original_file)
    Resque.redis.hset("request", request_id, request.to_json)
    proc {
      DBEE::Job::Download.perform(request_id, running_job, args, output)
    }.should raise_error

    # 元に戻す
    File.open(@original_file, "wb") { |f|
      f.print favicon
    }
  end

  it "performs downloading w/ material does not match SHA256" do
    request = @json_download_job.dup
    request["run_list"][0]["args"]["base_url"] = "http://192.168.5.3:9393/coverage/assets/0.4.4/"
    request["program"]["filename"] = "favicon.png"
    request_id  = request["request_id"]
    running_job = request["running_job"]
    args        = request["run_list"][0]["args"]
    output      = request["run_list"][0]["output"]
    Resque.redis.hset("request", request_id, request.to_json)

    # メタデータ内のSHA256を改変
    metadata = JSON.parse(File.open("#{@original_file}.json", "r").read)
    metadata["SHA256"] = "ABCDEFG"
    File.open("#{@original_file}.json", "w") { |f|
      f.print metadata.to_json
    }

    proc {
      DBEE::Job::Download.perform(request_id, running_job, args, output)
    }.should raise_error
  end

  it "performs downloading w/ invalid request id" do
    DBEE::Job::Download.instance_variable_set(:@request_id, "33333")
    DBEE::Job::Download.instance_variable_set(
      :@request_url,
     "#{DBEE::Config::API_URL}/request/33333"
    )

    proc {
      DBEE::Job::Download.delete_request("running_job")
    }.should raise_error
    proc {
      DBEE::Job::Download.get_request
    }.should raise_error
  end
end
