$LOAD_PATH.unshift File.dirname(__FILE__) + '/lib'

require 'resque/tasks'
load '../resque/tasks/redis.rake'
load 'config.rb'
require 'dbee/app'
require 'dbee/job'
require 'rspec/core/rake_task'

task :default => :test
task :spec => :test

unless ENV['REDIS'].nil?
  Resque.redis = ENV['REDIS']
end

RSpec::Core::RakeTask.new(:test)
