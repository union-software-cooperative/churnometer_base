require './lib/churn_db'
require 'open3.rb'

class ImportPresenter

  def db 
    @db ||= Db.new
  end
  
  def dimensions
    @dimensions ||= Dimensions.new # Dimensions is stubbed out, expecting integration with David's column generalisation code
  end
  
  def dbm
    @dbm ||= DatabaseManager.new
  end
  
  def reset
    dbm.empty_membersource
    dbm.rebuild_displaytextsource
    dbm.rebuild_transactionsource
  end
  
  def go
    db.ex("select insertmemberfact()");
    db.ex("select inserttransactionfact()");
    db.ex("select updatedisplaytext()");
  end
  
  def diags
    <<-SQL
      #{dbm.transactionsource_sql};
      #{dbm.transactionsourceprev_sql};
      #{dbm.transactionfact_sql};
      #{dbm.inserttransactionfact_sql};
    SQL
  end
  
  def status
		mcnt = membersource_count
		dcnt = displaytextsource_count
		tcnt = transactionsource_count

  	mcnt_msg = (mcnt == "0" ? "No member data staged - expecting members.txt to be upload" : mcnt.to_s + " rows of member data staged for import")
  	dcnt_msg = (dcnt == "0" ? "No displaytext data staged - expecting displaytext.txt to be upload" : dcnt.to_s + " rows of displaytext data staged for import")
  	tcnt_msg = (tcnt == "0" ? "No transaction data staged - expecting transactions.txt to be upload" : tcnt.to_s + " rows of transaction data staged for import")
  	
  	<<-HTML
  		<ul>
  			<li>
  				#{mcnt_msg}
  			</li>
  			<li>
  				#{dcnt_msg}
  			</li>
  			<li>
  				#{tcnt_msg}
  			</li>
  		</ul>
		HTML
  end
  
  def membersource_count
    data = db.ex("select count(*) cnt from membersource")
  	data[0]['cnt']
  end
  
  def displaytextsource_count
    data = db.ex("select count(*) cnt from displaytextsource")
  	data[0]['cnt']
  end
  
  def transactionsource_count
    data = db.ex("select count(*) cnt from transactionsource")
  	data[0]['cnt']
  end
  
  def console_ex(cmd)
    err=nil
    result=nil
    
    Open3.popen3(cmd) do |i,o,e,t| 
      i.close_write # don't pipe anything in to stdin
      err = e.read
      result = o.read
    end
    if !err.nil? && !err.empty? 
      raise err
    end
    result
  end
  
  def member_import(file)
    dbm.empty_membersource
    console_ex(member_import_command(file))
  end

  def displaytext_import(file)
    dbm.rebuild_displaytextsource
    console_ex(displaytext_import_command(file))
  end
  
  def transaction_import(file)
    dbm.rebuild_transactionsource
    console_ex(transaction_import_command(file))
  end
  
  def member_import_command(file)
  	cmd = "psql -h localhost churnometer -c \"\\copy membersource (memberid, status" 
    
    dimensions.each do |d|
    	cmd << ", #{d.column_base_name}" 
    end
    
    cmd << ") from '#{file}' with delimiter as E'\\t' null as '' CSV HEADER\""
  end
  
  def displaytext_import_command(file)
  	cmd = "psql -h localhost churnometer -c \""
  	cmd << "\\copy displaytextsource (attribute, id, displaytext) " 
    cmd << "from '#{file}' with delimiter as E'\\t' null as '' CSV HEADER"
    cmd << "\""
  end
  
  def transaction_import_command(file)
  	cmd = "psql -h localhost churnometer -c \""
  	cmd << "\\copy transactionsource (id, creationdate, memberid, userid, amount) " 
    cmd << "from '#{file}' with delimiter as E'\\t' null as '' CSV HEADER"
    cmd << "\""
  end
  
end