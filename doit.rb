#!/opt/puppet/bin/ruby
 
require 'yaml'
 
#possible orch user, separate certname
#that way has no classification
#otherwise need to save off old classification
#blow away, and restore later
def main ()
  plan  = YAML.load_file(ARGV[0])
  machines = YAML.load_file(ARGV[1])
  runlist = resolve(plan, machines) 
  # reject the arity hashes from the all nodes list
  all = runlist.values.flatten.uniq.reject { |v| v.class == Hash }.sort
  stop_agent(all)
  #run_puppet(0, all)
  #backup_classification(all)
  runlist.each do |role, nodes|
    arity = nodes[0]["arity"]
    nodes = nodes.slice(1, nodes.length).flatten
    classify(nodes, role)
    run_puppet(arity, nodes)
  end
  #restore_classification(all)
  ##run_puppet(0, all, true)
  start_agent(all)
end



#####################################
def run_puppet (arity, nodes, noop=false)
  options = []
  if arity.integer? && arity > 0
    options << "--batch #{arity}"
  elsif arity.integer? && arity == 0
  else
    puts "arity should be a number greater than or equal to 0! arity = #{arity}"
  end

  if noop
    options << "--noop"
  end
  
  nodes.each do |node| options << "-I #{node}" end

  nodes.each do |node|
    statcmd = "/bin/su - peadmin -c \'mco puppet status -I #{node}\'"
    while %x(#{statcmd}) !~ /Currently stopped/
      puts "waiting for prior run to finish on #{node}..."
      sleep(1)
    end
  end
  puts "...ready on #{nodes}..."
  prefix = "/bin/su - peadmin -c"
  cmd = "\'mco puppet runonce #{options * ' '}\'"
  puts "...running puppet via mco with command: #{cmd}"
  command = "#{prefix} #{cmd}"
  result = %x(#{command})
  #puts result
end

def resolve (r,m)
  r.each do |k,v|
    t = []
    a = {}
    v.each do |e|
      if e['arity'] != nil
        a = e
      # try the lookup, if it succeeds, replace with machine(s)
      elsif m[e] != nil
        t << m[e]
      # otherwise assume it's a machine name itself
      else
        t << e
      end
    end
    r[k] = [a, t.flatten.uniq]
  end
  r
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
