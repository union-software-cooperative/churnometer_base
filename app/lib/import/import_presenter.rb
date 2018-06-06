#  Churnometer - A dashboard for exploring a membership organisations turn-over/churn
#  Copyright (C) 2012-2013 Lucas Rohde (freeChange)
#  lukerohde@gmail.com
#
#  Churnometer is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Churnometer is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with Churnometer.  If not, see <http://www.gnu.org/licenses/>.

require './lib/settings'
require './lib/churn_db'
require 'open3.rb'

class ImportPresenter
  def initialize(app, importer, db)
    @dbm = DatabaseManager.new(app)
    @dimensions = app.custom_dimensions
    @db = db
    @importer = importer
    @app = app
  end

  def db
    @db
  end

  def close_db
    @db.close_db()
    @dbm.close_db()
    @importer.close_db()
  end

  def dimensions
    @dimensions
  end

  def dbm
    @dbm
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
    @importer.import(import_date)
  end

  def diags
    <<-HTML
      <pre>
        #{dbm.fix_out_of_sequence_changes_sql};
      </pre>
    HTML
  end

  def importing?
    @importer.state == 'running'
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
          Importer State: #{@importer.state}
        </li>
        <li>
          Progress: #{@importer.progress}
        </li>
      </ul>
    HTML
  end

  def importer_status
    load_staging_counts

    mcnt_msg = (@mcnt == "0" ? "No member data staged - expecting members.txt to be upload" : @mcnt.to_s + " rows of member data staged for import")
    dcnt_msg = (@dcnt == "0" ? "No displaytext data staged - expecting displaytext.txt to be upload" : @dcnt.to_s + " rows of displaytext data staged for import")
    tcnt_msg = (@tcnt == "0" ? "No transaction data staged - expecting transactions.txt to be upload" : @tcnt.to_s + " rows of transaction data staged for import")

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
      <li>
        Background Importer State: #{@importer.state}
      </li>
      <li>
        Importer Progress: #{@importer.progress}
      </li>
      </ul>
    HTML
  end

  def staging_status
    <<-HTML
      #{importer_status}
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
        <thead>
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
        </thead>
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
    data = db.ex("select creationdate, count(*) cnt from transactionfact group by creationdate order by creationdate desc")
  end

  def member_import_history
    data = db.ex("select changedate as creationdate, count(*) cnt from memberfact group by changedate order by changedate desc")
  end

  def console_ex(cmd)
    err=nil
    result=nil

    Open3.popen3(cmd) do |i,o,e,t|
      i.close_write # don't pipe anything in to stdin
      err = e.read
      result = o.read
    end
    if !(err.nil? || err.empty?)
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

  def backup(file)
    console_ex(backup_command(file))
  end

  def download_source(file)
    console_ex(download_source_command(file))
  end

  def member_import_command(file)
    cmd = "PGPASSWORD=\"#{@db.pass}\" psql #{@db.dbname} -h #{@db.host} -U #{@db.user} -c \"\\copy membersource (memberid, status"

    dimensions.each do |d|
      cmd << ", #{d.column_base_name}"
    end

    cmd << ") from '#{file}' with delimiter as E'\\t' null as '' CSV HEADER\""
  end

  def displaytext_import_command(file)
    cmd = "PGPASSWORD=\"#{@db.pass}\" psql #{@db.dbname} -h #{@db.host} -U #{@db.user} -c \""
    cmd << "\\copy displaytextsource (attribute, id, displaytext) "
    cmd << "from '#{file}' with delimiter as E'\\t' null as '' CSV HEADER"
    cmd << "\""
  end

  def transaction_import_command(file)
    cmd = "PGPASSWORD=\"#{@db.pass}\" psql #{@db.dbname} -h #{@db.host} -U #{@db.user} -c \""
    cmd << "\\copy transactionsource (id, creationdate, memberid, userid, amount) "
    cmd << "from '#{file}' with delimiter as E'\\t' null as '' CSV HEADER"
    cmd << "\""
  end

  def backup_command(file)
    data_file = "backup/#{@db.dbname}_db_backup.sql"
    cmd = "PGPASSWORD=\"#{@db.pass}\" pg_dump #{@db.dbname} -h #{@db.host} -U #{@db.user} > #{data_file}"
    cmd << "; rm -Rf #{file}"
    cmd << "; zip -q -r #{file} . -x \"backup\/backup.zip\" -x \"uploads\/*\" -x \"tmp\/*\" -x \".sass-cache\/*\"  -x \"pids\/*\" "
    cmd << "; rm #{data_file}"
  end

  # todo refactor to somewhere more sensible
  def download_source_command(file)
    source_repo = @app.config['source_repo']

    cmd = "rm -Rf #{file}"
    cmd << "; rm -Rf #{file}.zip"
    cmd << "; mkdir #{file}"
    cmd << "; git clone #{source_repo} #{file}"
    cmd << "; cd #{file}"
    cmd << "; zip -q -r ../../#{file}.zip ."
  end

  def empty_cache
    console_ex("rm -f tmp/*.Marshal")
  end

  def restart
    cmd = ""
    if @app.config['host_os'].to_s == "osx"
      cmd = "killall ruby; thin start" # "killall ruby; thin start"
    else
      # requires passwordless sudo for postgresql and thin - see install script
      cmd = "sudo systemctl restart postgresql"
      cmd << "; rm -f tmp/*.Marshal"
      cmd << "; sudo systemctl restart churnometer & "
    end
    exec(cmd) # terminates current thin session, so nothing will be executed after this
  end
end
