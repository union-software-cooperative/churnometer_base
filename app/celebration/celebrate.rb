require 'pg'
require 'yaml'
require 'date'

config = YAML.load_file('celebration.yaml')
db_config = YAML.load_file('../config/config_site.yaml')['database']
db = PG.connect(db_config.reject{|k,v| k == 'facttable'})

config.each do |c|
  puts c 
  f = "#{c['name']}.done"
  unless File.exist?(f)
    if db.exec(c['sql']).first['target_met']
      `cp #{c['image']} ../public/images/celebration.gif`
      `echo '#{c['caption']}' > ../public/celebration.txt`
      `touch "#{f}"`
    end
  else
    if File.mtime(f).to_date + c['duration_days'].to_i <= Date.today  
      `rm ../public/images/celebration.gif ../public/celebration.txt`
    end  
  end
end 


