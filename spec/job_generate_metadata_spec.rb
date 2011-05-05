# vim:fileencoding=utf-8

require File.dirname(__FILE__) + '/spec_helper'
require 'dbee/job'

describe 'DBEE Generating Metadata Job' do
  before(:all) do
    @material_dir = DBEE::Config::MATERIAL_DIR
    @original_file = Pathname.new(File.dirname(__FILE__) + '/../coverage/assets/0.4.4/favicon.png')
    DBEE::Config::MATERIAL_DIR.replace(File.dirname(__FILE__) + '/../coverage/assets/0.4.4')
    @json_job = {
      "requester"   => "rspec.tokyo",
      "running_job" => "DBEE::Job::GenerateMetadata",
      "request_id" => "1",
      "run_list" => [
        {
          "name" => "DBEE::Job::GenerateMetadata",
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

    # 比較用メタデータ
    digest = Digest::SHA256.hexdigest(File.open(@original_file).read)
    @metadata = {
      "filename" => @original_file.basename,
      "size"     => @original_file.size,
      "SHA256"   => digest,
      "mtime"    => @original_file.mtime,
      "ctime"    => @original_file.ctime
    }.to_json
  end

  after(:all) do
    File.unlink("#{@original_file}.json")
  end

  it 'generates metadata in JSON' do
    # まずリクエストをJSONにして直接Redisへ入れる
    json_job = @json_job.dup
    request_id  = json_job["request_id"]
    running_job = json_job["running_job"]
    args        = json_job["run_list"][0]["args"]
    output      = json_job["run_list"][0]["output"]

    Resque.redis.hset("request", request_id, json_job.to_json)
    DBEE::Job::GenerateMetadata.perform(request_id, running_job, args, output)

    # 生成されたJSONが予め作成したものと一致するか
    generated_metadata = JSON.parse(File.open("#{@original_file}.json", "r").read)
    generated_metadata.should == JSON.parse(@metadata)
  end

  it 'try to generates metadata but already exist. skipped...' do
    # まずリクエストをJSONにして直接Redisへ入れる
    json_job = @json_job.dup
    request_id  = json_job["request_id"]
    running_job = json_job["running_job"]
    args        = json_job["run_list"][0]["args"]
    output      = json_job["run_list"][0]["output"]

    Resque.redis.hset("request", request_id, json_job.to_json)

    # メタデータを生成して、GenerateMetadataによって生成される場所に保存した場合、
    # 上書きはされない
    File.open("#{@original_file}.json", "w") do |f|
      f.print "HOMUHOMU"
    end

    DBEE::Job::GenerateMetadata.perform(request_id, running_job, args, output)
    File.open("#{@original_file}.json", "r").read.should == "HOMUHOMU"
  end

  it 'try to generates metadata but material does not exist' do
    # まずリクエストをJSONにして直接Redisへ入れる
    json_job = @json_job.dup
    request_id  = json_job["request_id"]
    running_job = json_job["running_job"]
    args        = json_job["run_list"][0]["args"]
    output      = json_job["run_list"][0]["output"]

    # 存在しないファイル名にする
    json_job["program"]["filename"] = "notfound!!!.ts"

    Resque.redis.hset("request", request_id, json_job.to_json)

    proc {
      DBEE::Job::GenerateMetadata.perform(request_id, running_job, args, output)
    }.should raise_error("material not found")
  end
end
