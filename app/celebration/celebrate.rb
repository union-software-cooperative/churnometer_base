require 'pg'
require 'yaml'
require 'date'
require 'pry-byebug'

config = YAML.load_file('celebration.yaml')
db_config = YAML.load_file('../config/config_site.yaml')['database']
db = PG.connect(db_config.reject{|k,v| k == 'facttable'})

config.each do |k,c|
  puts "evaluating #{k}..."
  fd = "#{k}.done"
  fc = "#{k}.celebrating"
  unless File.exist?(fd) || File.exists?(fc)
    result = db.exec(c['sql']).first
    if result['target_met']
      puts "celebrating #{k} since #{result['progress']} of #{result['target']} has been achieved."
      `cp #{c['image']} ../public/images/celebration.gif`
      `echo '#{c['caption']}' > ../public/celebration.txt`
      Dir['*.celebrating'].each do |f|
        puts "prematurely completing #{f} due to new celebrations!"
        `mv #{f} $(basename #{f} .celebrating).done`
      end
      `touch "#{fc}"`
    else 
      puts "skipping #{k} since only #{result['progress']} of #{result['target']} hasn't been met."
    end
  else
    if File.exists?(fc)
      if File.mtime(fc).to_date + c['duration_days'].to_i <= Date.today  
        puts "completing #{k} celebrations"
        `rm ../public/images/celebration.gif ../public/celebration.txt`
        `mv "#{fc}" "#{fd}"`
      else 
        puts "still celebrating #{k}"
      end
    else 
      puts "skipping #{k} since it has finished."
    end  
  end
end 


