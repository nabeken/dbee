# load master, material, worker
%w{
  master.god
  material-worker.god
}.each do |f|
  God.load File.dirname(__FILE__) + "/#{f}"
end
