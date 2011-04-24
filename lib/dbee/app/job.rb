require 'sinatra/base'
require 'resque'
require 'json'

module DBEE
  class App
    class Job < Sinatra::Base
      # return json which contains queue lists
      get '/' do
        # get all queue names
        queues = Resque.queues
        all_jobs = {}
        queues.each do |q|
          # IDを生成
          jobs = Resque.peek(q, 0, 0)
          jobs.each_with_index do |j, i|
            j["id"] = "#{i}"
          end
          all_jobs[q] = jobs
        end

        content_type :json
        all_jobs.to_json
      end
    end
  end
end
