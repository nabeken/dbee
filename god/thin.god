# coding:utf-8
# vim:filetype=ruby
require 'facter'
Facter.to_hash
node = Facter.value(:fqdn)
rakefile = File.dirname(__FILE__) + '/../Rakefile'
load File.dirname(__FILE__) + '/../config.rb'

# thin
God.watch do |w|
  w.name     = "dbee-thin"
  w.group    = "dbee"
  w.interval = 30.seconds
  w.start    = "thin start --address 127.0.0.1 --port 9393 --daemonize"
  w.stop     = "thin stop --address 127.0.0.1 --port 9393 --daemonize"
  w.restart  = "thin restart --address 127.0.0.1 --port 9393 --daemonize"
  w.dir      = File.dirname(__FILE__) + '/../'
  w.pid_file = w.dir + 'tmp/pids/thin.pid'
  #w.uid      = "root"
  #w.gid      = "root"
  w.log      = "/tmp/god-thin.log"

  # init状態のとき、process_runningがtrueならupへ遷移、falseならstartへ遷移
  # startに遷移すると w.start が実行される
  w.transition(:init, {true => :up, false => :start}) do |on|
    on.condition(:process_running) do |c|
      c.running = true
    end
  end

  # startまたはrestart状態の時upへ遷移する
  w.transition([:start, :restart], :up) do |on|
    on.condition(:process_running) do |c|
      c.running = true
      c.interval = 5.seconds
    end

    on.condition(:tries) do |c|
      c.times = 5
      c.transition = :start
      c.interval = 5.seconds
    end
  end

  w.transition(:up, :start) do |on|
    on.condition(:process_running) do |c|
      c.running = false
    end
  end
end
