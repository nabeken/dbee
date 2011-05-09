# vim:fileencoding=utf-8

require 'sinatra/base'
require 'resque'

module DBEE
  class App < Sinatra::Base
    @dir = File.dirname(File.expand_path(__FILE__))
    set :views,  "#{@dir}/app/views"
    set :public, "#{@dir}/app/public"

    get '/' do
      info = Resque.info
      out = "<html><head><title>Resque Demo</title></head><body>"
      out << "<p>"
      out << "There are #{info[:pending]} pending and "
      out << "#{info[:processed]} processed jobs across #{info[:queues]} queues."
      out << "</p>"
      out << '&nbsp;&nbsp;<a href="/resque/">View Resque</a>'
      out << "</body></html>"
      out
    end
  end
end
