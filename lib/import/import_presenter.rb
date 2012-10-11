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
  
  def rebuild
    dbm.rebuild
  end
  
  def go(import_date)
    $importer.import(import_date)
  end
  
  def diags
    <<-HTML
      <pre>
        #{dbm.memberchangefromlastchange_sql};
        #{dbm.memberchangefrommembersourceprev_sql};
      </pre>
    HTML
  end
  
  def importing?
    $importer.state == :running
  end
  
  def load_staging_counts
    @mcnt ||= membersource_count
		@dcnt ||= displaytextsource_count
		@tcnt ||= transactionsource_count
  end
  
  def import_ready?
    load_staging_counts
  
    if @mcnt != "0" && @dcnt != "0" && @tcnt !="0"
      true
    else
      false
    end
  end
  
  def import_status
    <<-HTML
      <h3>
        Importing...
      </h3>
      <ul>
        <li>
          Importer State: #{$importer.state}
        </li>
        <li>
          Progress: #{$importer.progress}
        </li>
      </ul>
    HTML
  end
  
  def staging_status
    
		load_staging_counts
		
  	mcnt_msg = (@mcnt == "0" ? "No member data staged - expecting members.txt to be upload" : @mcnt.to_s + " rows of member data staged for import")
  	dcnt_msg = (@dcnt == "0" ? "No displaytext data staged - expecting displaytext.txt to be upload" : @dcnt.to_s + " rows of displaytext data staged for import")
  	tcnt_msg = (@tcnt == "0" ? "No transaction data staged - expecting transactions.txt to be upload" : @tcnt.to_s + " rows of transaction data staged for import")
  	
  	<<-HTML
  	  <h3>
  	    Prior imports
  	  </h3>
  	  #{import_history}
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
  			<li>
  			  Background Importer State: #{$importer.state}
  			</li>
  			<li>
  			  Importer Progress: #{$importer.progress}
  			</li>
  		</ul>
		HTML
  end
  

  
  def import_history
    
    # merge member import history and transaction import history
    tab = {}
    member_import_history.each do |row| 
      tab[row['creationdate']] = {}
      tab[row['creationdate']]['members'] = row['cnt']
    end
    
    transaction_import_history.each do |row| 
      tab[row['creationdate']] ||= {}
      tab[row['creationdate']]['transactions'] = row['cnt']
    end
    
    # render table of history
    html = <<-HTML
      <table>
        <tr>
          <th>
            import date
          </th>
          <th>
            member changes
          </th>
          <th>
            transaction changes
          </th>
        </tr>
    HTML
    
    tab.each do |k,v|
      html << <<-HTML
         <tr>
          <td>
            #{k}
          </td>
          <td>
            #{v['members']}
          </td>
          <td>
            #{v['transactions']}
          </td>
        </tr>
      HTML
    end
    html << '</table>'
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
  
  def transaction_import_history
    data = db.ex("select creationdate, count(*) cnt from transactionfact group by creationdate order by creationdate")
  end
  
  def member_import_history
    data = db.ex("select changedate as creationdate, count(*) cnt from memberfact group by changedate order by changedate")
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
  
  # The following import functionality could arguably go into the db manager
  # Except the db manager is more about configuring the database
  # An this is more about importing.  It could go into database_importer but 
  # That is about executing the import in the background.
  
  def member_import(file)
    dbm.empty_membersource
    console_ex(member_import_command(file))
    db.ex("VACUUM membersource;")
    db.ex("ANALYSE membersource;")
    console_ex("mv \"#{file}\" \"#{file}.imported\"")
  end

  def displaytext_import(file)
    dbm.rebuild_displaytextsource
    console_ex(displaytext_import_command(file))
    db.ex("VACUUM displaytextsource;")
    db.ex("ANALYSE displaytextsource;")
    console_ex("mv \"#{file}\" \"#{file}.imported\"")
  end
  
  def transaction_import(file)
    dbm.rebuild_transactionsource
    console_ex(transaction_import_command(file))
    db.ex("VACUUM transactionsource;")
    db.ex("ANALYSE transactionsource;")
    console_ex("mv \"#{file}\" \"#{file}.imported\"")
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