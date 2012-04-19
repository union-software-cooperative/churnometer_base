class Db
  def initialize
    @conn = PGconn.open(
      :host =>      Config['database']['host'],
      :port =>      Config['database']['port'],
      :dbname =>    Config['database']['dbname'],
      :user =>      Config['database']['user'],
      :password =>  Config['database']['password']
    )
  end
  
  def ex(sql)
    @conn.exec(sql)
  end
end


class ChurnDB
  attr_reader :db
  attr_reader :params
  attr_reader :sql
  attr_reader :cache_hit
  
  def initialize()
  end
  
  def db
    @db ||= Db.new
  end
  
  def ex(sql)
    @cache_hit = false
    db.ex(sql)
  end  
  
  def summary_sql(header1, start_date, end_date, transactions, site_constraint, filter_xml)
    <<-SQL
      select * 
      from summary(
        'memberfacthelper4',
        '#{header1}', 
        '',
        '#{start_date.strftime(DateFormatDB)}',
        '#{(end_date+1).strftime(DateFormatDB)}',
        #{transactions.to_s}, 
        '#{site_constraint}',
        '#{filter_xml}'
        )
    SQL
  end
    
  def summary(header1, start_date, end_date, transactions, site_constraint, filter_xml)
    @sql = summary_sql(header1, start_date, end_date, transactions, site_constraint, filter_xml)
    ex(@sql)
  end
  
  def summary_running_sql(header1, interval, start_date, end_date, transactions, site_constraint, filter_xml)
    <<-SQL
      select * 
      from summary_running(
        'memberfacthelper4',
        '#{header1}', 
        '#{interval}',
        '#{start_date.strftime(DateFormatDB)}',
        '#{(end_date+1).strftime(DateFormatDB)}',
        #{transactions.to_s}, 
        '#{site_constraint}',
        '#{filter_xml}'
        )
    SQL
  end
  
  def summary_running(header1, interval, start_date, end_date, transactions,  site_constraint, filter_xml)
    @sql = summary_running_sql(header1, interval, start_date, end_date, transactions, site_constraint, filter_xml)
    ex(@sql)
  end
  
  def detail_sql(header1, filter_column, start_date, end_date, transactions,  site_constraint, filter_xml)
    
    if static_cols.include?(filter_column)
    
      member_date = filter_column.include?('start') ? start_date : (end_date+1)
      site_date = ''
      if site_constraint == 'end' 
        site_date = end_date
      end
      if site_constraint == 'start' 
        site_date = start_date
      end
      
      filter_column = filter_column.sub('_start_count', '').sub('_end_count', '')
    
      sql = <<-SQL 
        select * 
        from detail_static_friendly(
           'memberfacthelper4',
          '#{header1}', 
          '#{filter_column}',  
          '#{member_date}',
          #{site_date == '' ? 'NULL' : "'#{site_date}'"},
          '#{filter_xml}'
          )
      SQL
    else
      sql = <<-SQL 
        select * 
        from detail_friendly(
          'memberfacthelper4',
          '#{header1}', 
          '#{filter_column}',  
          '#{start_date.strftime(DateFormatDB)}',
          '#{(end_date+1).strftime(DateFormatDB)}',
          #{transactions.to_s}, 
          '#{site_constraint}',
          '#{filter_xml}'
          )
      SQL
    end
    
    sql
  end
  
  def detail(header1, filter_column, start_date, end_date, transactions,  site_constraint, filter_xml)
    @sql = detail_sql(header1, filter_column, start_date, end_date, transactions,  site_constraint, filter_xml)
    ex(@sql)
  end
  
  def transfer_sql(start_date, end_date, site_constraint, filter_xml)
    
    sql = <<-SQL
      select
        changedate
        , sum(a1p_other_gain + paying_other_gain) transfer_in
        , sum(-a1p_other_loss - paying_other_loss) transfer_out
        from
          detail_friendly(
            'memberfacthelper4',
            'status',
            '',
            '#{start_date.strftime(DateFormatDB)}',
            '#{(end_date+1).strftime(DateFormatDB)}',
            false,
            '#{site_constraint}',
            '#{filter_xml}'
          )
        where
          paying_other_gain <> 0
          or paying_other_loss <> 0
          or a1p_other_gain <> 0
          or a1p_other_loss <> 0
        group by
          changedate
        order by
          changedate
    SQL

    sql
  end
  
  def get_transfers(start_date, end_date, site_constraint, filter_xml)
    @sql = transfer_sql(start_date, end_date, site_constraint, filter_xml)
    ex(@sql)
  end

  def getdimstart_sql(group_by)
    # TODO refactor default group_by branchid
    <<-SQL
      select getdimstart('#{(group_by || 'branchid')}') 
    SQL
  end
  
  def getdimstart(group_by)
    ex(getdimstart_sql(group_by))
  end

  def get_display_text_sql(column, id)
     <<-SQL
       select displaytext from displaytext where attribute = '#{column}' and id = '#{id}' limit 1
     SQL
  end
  
  def get_display_text(column, id)
    t = "error!"
    
    if id == "unassigned" 
      t = "unassigned"
    else
      val = db.ex(get_display_text_sql(column,id))
      
      if val.count != 0 
        t = val[0]['displaytext']
      end
    end 
    
    t
  end

  private

  def static_cols
    [
      'a1p_end_count',
      'a1p_start_count',
      'paying_end_count',
      'paying_start_count',
      'stopped_start_count',
      'stopped_end_count'
    ]
  end

end


class ChurnDBDiskCache < ChurnDB
  
  @@cache_status = "Not in use."
  
  def self.cache_status
    @@cache_status
  end
  
  def self.cache_status=(status)
    @@cache_status = status
  end
  
  def self.cache
    if !defined? @@cache
      load_cache
    end
    
    @@cache
  end
  
  def initialize
    ChurnDBDiskCache.cache_status = "" #The data is initialised every request but in production the cache should persist, this lets cache status to accumulated across during the page life
  end
  
  def ex(sql)
     filename = ChurnDBDiskCache.cache[sql]

     if filename.nil? || !File.exists?(filename)
       @cache_hit = false
       ChurnDBDiskCache.cache_status += 'cache miss. '
       
       # load data from database
       data = db.ex(sql)

       # convert data into serializable form
       result = Array.new
       data.each do |r|
         result << r
       end
       
       ChurnDBDiskCache.update_cache(sql, result)
     else
       @cache_hit = true
       ChurnDBDiskCache.cache_status += "cache hit (#{filename}). "
       
       # load data from cache file
       data = ""
       File.open(filename, 'r') do |f|
         while line=f.gets
           data+=line
         end
       end

       result = Marshal::load(data)
     end

     result
   end
   
private
  
  def self.load_cache
      begin
        data = ""
        File.open('tmp/cache.Marshal', 'r') do |f|
          while line=f.gets
            data+=line
          end
        end
            
        @@cache = Marshal::load(data)
        ChurnDBDiskCache.cache_status += "Cache reloaded. "
      rescue
        @@cache = Hash.new
        #throw "failed to load cache"
        ChurnDBDiskCache.cache_status += "Failed to load cache. "
      end
  end
  
  def self.update_cache(sql, result)
    filename = "tmp/cache-#{self.cache.size.to_s}.Marshal" # use index as filename
    
    #write data to file
    File.open(filename, 'w') do |f|
      f.puts Marshal::dump(result)
    end
    
    #update index
    @@cache[sql] = filename 
    File.open('tmp/cache.Marshal', 'w') do |f|
      f.puts Marshal::dump(@@cache)
    end
  end
    
end

