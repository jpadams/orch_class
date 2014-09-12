#!/opt/puppet/bin/ruby
 
require 'yaml'
 
#possible orch user, separate certname
#that way has no classification
#otherwise need to save off old classification
#blow away, and restore later
def main ()
  runlist = YAML.load_file(ARGV[0])
  all = runlist.values.flatten.uniq.sort 
  stop_agent(all)
  run_puppet(all)
  #backup_classification(all)
  runlist.each do |role, nodes| #arity?
    classify(nodes, role)
    run_puppet(nodes)
  end
  #restore_classification(all)
  run_puppet(all, true)
  start_agent(all)
end



#####################################
def run_puppet (nodes, noop=false)
  nodes.each do |node|
    statcmd = "/bin/su - peadmin -c \'mco puppet status -I #{node}\'"
    while %x(#{statcmd}) !~ /Currently stopped/
      puts "waiting for prior run to finish on #{node}..."
      sleep(1)
    end
    if noop
      puts "...ready on #{node}..."
      command = "/bin/su - peadmin -c \'mco puppet runonce --noop -I #{node}\'"
      puts "...running in noop mode on #{node}..."
    else
      puts "...ready on #{node}..."
      command = "/bin/su - peadmin -c \'mco puppet runonce -I #{node}\'"
      puts "...running puppet on #{node}..."
    end
    result = %x(#{command}) 
  end
end

RAKE = "/opt/puppet/bin/rake -f /opt/puppet/share/puppet-dashboard/Rakefile RAILS_ENV=production"

backups = {} 

def backup (node,classes) 
#def backup (n,g,c,p,v) 
  backups[node] = classes 
#  h["groups"] = g
#  h["parameters"] = p
#  h["variables"] => v
end

def backup_classification (nodes)
 nodes.each do |node|
    command = "#{RAKE} node:listclasses[\'#{node}\']"
    c = %x(#{command}).split("\n")
    #backups << backup(node, g, c, p, v)
    backups << backup(node,c)
  end
end

def restore_classification (nodes)
  nodes.each do |node|
    command = "#{RAKE} node:classes[\'#{node}\',\'#{classes}\']"
    result = %x(#{command})
  end
end

def classify (nodes, role)
  nodes.each do |node|
    prepcmd = "#{RAKE} nodeclass:add[\'#{role}\','skip']"
    command = "#{RAKE} node:classes[\'#{node}\',\'#{role}\']"
    puts "...classifying #{node} with role of #{role}..."
    %x(#{prepcmd})
    result = %x(#{command})
  end
end

def stop_agent (nodes)
  nodes.each do |node|
    statcmd = "/bin/su - peadmin -c \'mco puppet status -I #{node}\'"
    while %x(#{statcmd}) !~ /Currently stopped|idling/
      puts "waiting for puppet to quiesce on #{node} before stopping..."
      sleep(1)
    end
    puts "...stopping agent service on #{node}..."
    command = "/bin/su - peadmin -c \'mco service pe-puppet stop -I #{node}\'"
    result = %x(#{command})
  end
end 

def start_agent (nodes)
  nodes.each do |node|
    puts "...starting agent service on #{node}..."
    command = "/bin/su - peadmin -c \'mco service pe-puppet start -I #{node}\'"
    result = %x(#{command})
  end
end 

main()
