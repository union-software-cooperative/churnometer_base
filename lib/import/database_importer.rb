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

  attr_accessor :state
  attr_accessor :progress
  attr_accessor :import_date
  
  def db 
    @db ||= Db.new(@app)
  end

  def initialize(app)
    @state = :stopped
    @progress = ""
    @app = app
  end
  
  def import(import_date)
    raise "Aleady importing!" if @state == :running
    raise "Importer not started.  Execute Importer.run" if @state == :stopped
    @progress="Starting..."
    @import_date = import_date
    @state=:running # The background loop could begin, any instant after it is set
  end
  
  def run
    raise "Importer already started!"  if @state != :stopped 
    @state = ":idle"
          
    Thread.new do
      while @state != :stopped
        if @state == :running
          begin
            go
            @state = ":idle"
          rescue StandardError => err
            @progress += ". An error occurred - " + err.message
            @state = :broken
	    @db = nil # if a connection is lost or terminated during import, this will force a new connection next time
          end
        end
        sleep 1
      end
    end
  end

  private
  
  def state=(v)
    #prevent public setting of state
    @state = v
  end
  
  def go
    start_time = Time.now
    db.async_ex("update importing set importing = 1")
    
    @progress = "Step 1. Inserting member changes"
    db.async_ex("select insertmemberfact('#{@import_date}')")
    db.async_ex("vacuum memberfact")
    db.async_ex("vacuum membersourceprev")
    db.async_ex("analyse memberfact")
    db.async_ex("analyse membersourceprev")
    
    @progress = "Step 2. Inserting new transactions"
    db.async_ex("select inserttransactionfact('#{@import_date}')")
    db.async_ex("vacuum transactionfact")
    db.async_ex("analyse transactionfact")

    @progress = "Step 3. Updating displaytext"
    db.async_ex("select updatedisplaytext()")
    db.async_ex("vacuum displaytext")
    db.async_ex("analyse displaytext")
    
    @progress = "Step 4. Precalculating member change data"
    db.async_ex("select updatememberfacthelper()")
    db.async_ex("vacuum memberfacthelper")
    db.async_ex("analyse memberfacthelper")

    db.async_ex("update importing set importing = 0")
    end_time = Time.now
    
    @progress = "Import successfully finished at #{end_time} and took #{(end_time - start_time)/60} minutes."
  end 
end 
