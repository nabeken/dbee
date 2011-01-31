$LOAD_PATH.unshift File.dirname(__FILE__) + '/lib'

require 'resque/tasks'
load '../resque/tasks/redis.rake'
load 'config.rb'
require 'dbee/app'

unless ENV['REDIS'].nil?
  Resque.redis = ENV['REDIS']
end
