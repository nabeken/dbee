# vim:fileencoding=utf-8

require File.dirname(__FILE__) + '/spec_helper'
require 'dbee/job'

describe 'DBEE Upload to S3 Job' do
  before(:all) do
    @original_file = Pathname.new(File.dirname(__FILE__) + '/../coverage/assets/0.4.4/favicon.png')
    @json_job = {
      "requester"   => "rspec.tokyo",
      "running_job" => "DBEE::Job::Upload::S3",
      "request_id" => "1",
      "run_list" => [
        {
          "name" => "DBEE::Job::Upload::S3",
          "args" => {},
          "output" => {}
        }
      ],
      "program" => {
        "name"          => "まどか",
        "ch"            => "TBS",
        "filename"      => "favicon.png"
      }
    }
    RightAws::S3.module_eval {
      def initialize(*args)
        RSpec::Mocks::setup(self)
        @interface = double('interface')
        @interface.stub(:list_all_my_buckets).and_return(['dbee'])
        @interface.stub(:store_object).and_return(
          'etag' => 'ETAG'
        )
        @interface.stub(:get_link)
      end

      def bucket(*args)
        'dbee'
      end
    }
  end

  it 'says :encode2 on queue() when @host_based_queue sets to :encode2' do
    DBEE::Job::Upload::S3.instance_variable_set(:@host_based_queue, :encode2)
    DBEE::Job::Upload::S3.queue.should == :encode2
  end

  it 'uploads to s3 but MD5 checksum does not match. finally fail' do
    json_job = @json_job.dup
    json_job["run_list"][0]["output"]["file"] = @original_file.to_s
    json_job["run_list"][0]["output"]["MD5"] = "etag"

    # まずリクエストをJSONにして直接Redisへ入れる
    request_id  = json_job["request_id"]
    running_job = json_job["running_job"]
    args        = json_job["run_list"][0]["args"]
    output      = json_job["run_list"][0]["output"]

    Resque.redis.hset("request", request_id, json_job.to_json)

    proc {
      DBEE::Job::Upload::S3.perform(request_id, running_job, args, output)
    }.should raise_error(/MD5 checksum does not match/)
  end

  it 'successfully uploads to s3' do
    json_job = @json_job.dup
    json_job["run_list"][0]["output"]["file"] = @original_file.to_s
    json_job["run_list"][0]["output"]["MD5"] = "ETAG"

    # まずリクエストをJSONにして直接Redisへ入れる
    request_id  = json_job["request_id"]
    running_job = json_job["running_job"]
    args        = json_job["run_list"][0]["args"]
    output      = json_job["run_list"][0]["output"]

    Resque.redis.hset("request", request_id, json_job.to_json)
    proc {
      DBEE::Job::Upload::S3.perform(request_id, running_job, args, output)
    }.should_not raise_error
  end

  it 'uploads to s3 but output file does not exist. finally fail' do
    notfound = "/tmp/notfound.jpeg.notfound"
    json_job = @json_job.dup
    json_job["run_list"][0]["output"]["file"] = notfound
    json_job["run_list"][0]["output"]["MD5"] = "ETAG"

    # まずリクエストをJSONにして直接Redisへ入れる
    request_id  = json_job["request_id"]
    running_job = json_job["running_job"]
    args        = json_job["run_list"][0]["args"]
    output      = json_job["run_list"][0]["output"]

    Resque.redis.hset("request", request_id, json_job.to_json)

    proc {
      DBEE::Job::Upload::S3.perform(request_id, running_job, args, output)
    }.should raise_error("File not found. #{notfound}")
  end
end
