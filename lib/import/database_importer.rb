require './lib/churn_db'

class Importer

  attr_accessor :state
  attr_accessor :progress
  attr_accessor :import_date
  
  def db 
    @db ||= Db.new
  end

  def initialize
    @state = :stopped
    @progress = ""
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
    db.async_ex("analyse memberfact")
    
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