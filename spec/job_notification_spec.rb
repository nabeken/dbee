# coding:utf-8

require File.dirname(__FILE__) + '/spec_helper'
require 'dbee/job'
require 'pony'
require 'nkf'

describe DBEE::Job::Notification do
  before(:all) do
  end

  it "send notificaton to args[\"to\"]" do
    json_job = {
      "requester"   => "rspec.tokyo",
      "running_job" => "DBEE::Job::Notification",
      "request_id" => "1",
      "run_list" => [
        {
          "name" => "DBEE::Job::Notification",
          "args" => {
            "to" => "rspec@example.org"
          }
        }
      ],
      "ran_list" => [
        {
          "name" => "DBEE::Job::Download",
          "output" => {
            "job_started_at"  => Time.now.to_a,
            "job_finished_at" => Time.now.to_a,
            "size" => 1000
          }
        },
        {
          "name" => "DBEE::Job::Encode::IPAD",
          "output" => {
            "job_started_at"  => Time.now.to_a,
            "job_finished_at" => Time.now.to_a
          }
        },
        {
          "name" => "DBEE::Job::Upload",
          "output" => {
            "job_started_at"  => Time.now.to_a,
            "job_finished_at" => Time.now.to_a,
            "size" => 1000
          }
        }
      ],
      "program" => {
        "name"          => "まどか",
        "ch"            => "TBS",
        "filename"      => "favicon.png"
      }
    }
    # まずリクエストをJSONにして直接Redisへ入れる
    request_id  = json_job["request_id"]
    running_job = json_job["running_job"]
    args        = json_job["run_list"][0]["args"]

    # 引数内のToが引数のToと一致すればtrue
    Pony.stub(:mail) do |arg|
      arg[:to] == args["to"]
    end
    Pony.should_receive(:mail).and_return(true)

    Resque.redis.hset("request", request_id, json_job.to_json)
    DBEE::Job::Notification.perform(request_id, running_job, args)
  end
end
