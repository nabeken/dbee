require 'sinatra/base'
require 'resque'
require 'dbee/job'

module DBEE
  class App < Sinatra::Base
    get '/' do
    end
  end
end
