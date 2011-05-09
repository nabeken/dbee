# vim:fileencoding=utf-8

require File.dirname(__FILE__) + '/spec_helper'
require 'dbee/job'
require 'fileutils'

describe 'DBEE Encode Job for iPad' do
  before(:all) do
    @json_job = {
      "requester"   => "rspec.tokyo",
      "running_job" => "DBEE::Job::Encode::IPAD",
      "request_id" => "1",
      "run_list" => [
        {
          "name" => "DBEE::Job::Encode::IPAD",
          "args" => {
            "file" => "sample.ts"
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
    @sample_file = "#{DBEE::Config::Encode::OUTPUT_DIR}/iPad/sample.m4v"
    DBEE::Job::Encode::Config.module_eval {
      alias_method :_get_cmd, :get_cmd
      def get_cmd
        " @@ENCODE_OPTS@@ "
      end
    }
  end

  before(:each) do
    # サンプル用のファイルをtouchする
    FileUtils.mkdir_p(File.dirname(@sample_file))
    File.open(@sample_file, "w") do |f|
      f.puts "FIXME"
    end
  end

  after(:all) do
    DBEE::Job::Encode::Config.module_eval {
      undef get_cmd
      alias_method :get_cmd, :_get_cmd
    }
  end

  it "says :encode in queue()" do
    DBEE::Job::Encode::IPAD.queue.should == :encode
  end

  it "says :encode_2 in queue() via @host_based_queue" do
    DBEE::Job::Encode::IPAD.instance_variable_set(:@host_based_queue, :encode_2)
    DBEE::Job::Encode::IPAD.queue.should == :encode_2
  end

  it "successfully encodes using ffmpeg" do
    json_job = @json_job.dup
    # まずリクエストをJSONにして直接Redisへ入れる
    request_id  = json_job["request_id"]
    running_job = json_job["running_job"]
    args        = json_job["run_list"][0]["args"]
    Object.stub!(:system).and_return(true)
    Object.should_receive(:system).with("ffmpeg @@ENCODE_OPTS@@ \"#{@sample_file}\" >/dev/null 2>&1").and_return(true)
    Resque.redis.hset("request", request_id, json_job.to_json)
    DBEE::Job::Encode::IPAD.perform(request_id, running_job, args)
    File.exists?(@sample_file).should be_true
    File.unlink(@sample_file)
  end

  it "encodes using ffmpeg but fail" do
    json_job = @json_job.dup
    # まずリクエストをJSONにして直接Redisへ入れる
    request_id  = json_job["request_id"]
    running_job = json_job["running_job"]
    args        = json_job["run_list"][0]["args"]
    Object.stub!(:system).and_return(false)
    Resque.redis.hset("request", request_id, json_job.to_json)

    proc {
      DBEE::Job::Encode::IPAD.perform(request_id, running_job, args)
    }.should raise_error

    File.exists?(@sample_file).should be_false
  end
end
