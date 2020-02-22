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

require './lib/churn_db'

class Importer
  def db
    @db ||= Db.new(@app)
  end

  def initialize(app)
    @app = app
  end

  def import(date)
    raise "Aleady importing!" if self.state == 'running'

    self.progress="Starting import for '#{date}'..."
    self.import_date = date
    self.state='running' # The background loop could begin, any instant after it is set
    # Thread.new do
      begin
        @importing = true
        go
        self.state = 'idle'
        @importing = false
        self.close_db()
      rescue StandardError => err
        self.progress += ". An error occurred - " + err.message
        self.state = 'broken'
        @db = nil # if a connection is lost or terminated during import, this will force a new connection next time
      end
    # end
  end

  def close_db()
    @db.close_db() unless @db.nil? || @importing # probably rude, but keep db alive while importing
    @db = nil
  end

  def state()
    db.get_app_state('import_state') || 'stopped'
  end

  def progress()
    db.get_app_state('import_progress')
  end

  def import_date()
    db.get_app_state('import_date')
  end


  private

  def state=(v)
    #prevent public setting of state
    puts "SETTING IMPORT STATE TO '#{v}'"
    db.set_app_state('import_state', v)
  end

  def progress=(v)
    puts "SETTINGS IMPORT PROGRESS TO '#{v}''"
    db.set_app_state('import_progress', v)
  end

  def import_date=(v)
    puts "SETTING IMPORT DATE TO '#{v}'"
    db.set_app_state('import_date', v)
  end

  def go
    start_time = Time.now
    # Create import HTML file to trigger Nginx failover
    import_template = "import_off.html"
    import_file = "import.html"
    if File.exists?(import_template)
      File.open(import_file, "w") { |f| f.write File.read(import_template) }
    end

    db.async_ex("update importing set importing = 1")

    self.progress = "Step 1. Inserting member changes"
    db.async_ex("select insertmemberfact('#{self.import_date}')")
    db.async_ex("vacuum full analyse memberfact")
    db.async_ex("vacuum full analyse membersourceprev")

    self.progress = "Step 2. Inserting new transactions"
    db.async_ex("select inserttransactionfact('#{self.import_date}')")
    db.async_ex("vacuum full analyse transactionfact")
    db.async_ex("vacuum full analyse transactionsourceprev")

    self.progress = "Step 3. Updating displaytext"
    db.async_ex("select updatedisplaytext()")
    db.async_ex("vacuum full analyse displaytext")

    self.progress = "Step 4. Precalculating member change data"
    db.async_ex("select updatememberfacthelper()")
    db.async_ex("vacuum full analyse memberfacthelper")

    db.async_ex("update importing set importing = 0")

    # Remove import HTML to restore business as usual
    File.delete(import_file) if File.exists?(import_file)
    end_time = Time.now

    self.progress = "Import successfully finished at #{end_time} and took #{(end_time - start_time)/60} minutes."
  end
end
