# vim:fileencoding=utf-8
# vim:filetype=ruby
require 'facter'
Facter.to_hash
node = Facter.value(:fqdn)
rakefile = File.dirname(__FILE__) + '/../Rakefile'
load File.dirname(__FILE__) + '/../config.rb'

# material-worker node
# (material, worker)
{
  :upload   => [1, "upload_#{node}"],
  :worker   => [2, "encode_#{node},all_worker"]
}.each do |name, job|
  count = job.shift.to_s
  queue = job.shift
  God.watch do |w|
    w.name     = "dbee-#{name}"
    w.group    = "dbee"
    w.interval = 30.seconds
    w.env      = {"COUNT" => count, "QUEUE" => queue, "VVERBOSE" => "1"}
    w.start    = "#{DBEE::Config::RAKE} -f #{rakefile} resque:work"
    w.dir      = File.dirname(__FILE__) + '/../'
    #w.uid      = "root"
    #w.gid      = "root"
    w.log      = "/tmp/god-#{name}.log"

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
end
