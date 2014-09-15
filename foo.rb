runlist = {"orch_class::test1"=>["webservers", "loadbalancer", "centos65z"], "orch_class::test2"=>["loadbalancer"]}
machines = {"webservers"=>["centos65a", "centos65b"], "loadbalancer"=>["master"]} 

def munge(r, m)
  r.each do |k,v|
    t = []
    v.each do |e|
      t << m[e]
    end
    r[k] = t.flatten.uniq
  end
end


def resolve (r,m)
  r.each do |k,v|
    t = []
    v.each do |e|
     # try the lookup, if it succeeds, replace with machine(s)
      if m[e] != nil
        t << m[e]
     # otherwise assume it's a machine name itself
      else
        t << e
      end
    end
    r[k] = t.flatten.uniq
  end
  r
end
puts resolve(runlist,machines)
