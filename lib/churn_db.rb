require './lib/settings'
require 'time'
require 'pg'

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

  def async_ex(sql)
    @conn.async_exec(sql)
  end

  # Quotes the string as appropriate for insertion into an SQL query string.
  def quote(value)
    if value == true || value == false
      "#{value}"
    else
      "'#{value.to_s.gsub('\'', '\'\'')}'"
    end
  end

  # Quotes the given string assuming that it's intended to refer to a database element (column, 
  # table, etc) in an SQL query string.
  def quote_db(db_element_name)
    "\"#{db_element_name.gsub('\"', '\"\"')}\""
  end

  # Returns a string representing a literal array suitable for use in a query string. Individual elements
  # are quoted appropriately.
  # If 'type' is a string, then the return string also expresses a cast to the given sql data type.
  def sql_array(array, type=nil)
    result = "ARRAY[#{array.collect{ |x| quote(x) }.join(', ')}]"
    result << "::#{type}[]" if type
    result
  end

  # Returns the date portion of the given ruby Time object, formatted appropriately for use in a 
  # query string.
  def sql_date(time)
    quote(time.strftime(DateFormatDB))
  end
end


class ChurnDB
  include Settings

  attr_reader :db
  attr_reader :params
  attr_reader :sql
  attr_reader :cache_hit
  
  def initialize(app)
    @app = app
  end
  
  def db
    @db ||= Db.new
  end
  
  def ex(sql)
    @cache_hit = false
    db.ex(sql)
  end  

  def ex_async(sql)
    @cache_hit = false
    db.async_ex(sql)
  end  

  def database_config_key
    'database'
  end

  def fact_table
    Config[database_config_key()]['facttable']
  end

  def summary_sql(header1, start_date, end_date, transactions, site_constraint, filter_xml, filter_terms)
    if @app.use_new_query_generation_method?()
      raise "FilterTerms instance must be supplied to use new query method." if filter_terms.nil?

      query_class = query_class_for_group(header1)

      groupby_dimension = @app.dimensions[header1]
      raise "Invalid groupby dimension '#{groupby_dimension}'." if groupby_dimension.nil?

      @sql = query_class.new(@app, self, groupby_dimension, start_date, end_date, transactions, site_constraint, filter_terms).query_string
    else
      <<-SQL
        select * 
        from summary(
          '#{fact_table()}',
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
  end
    
  def summary(header1, start_date, end_date, transactions, site_constraint, filter_xml)
    @sql = summary_sql(header1, start_date, end_date, transactions, site_constraint, filter_xml)
    ex(@sql)
  end
  
  def summary_running_sql(header1, interval, start_date, end_date, transactions, site_constraint, filter_xml, filter_terms = nil)
    if @app.use_new_query_generation_method?()
      raise "FilterTerms instance must be supplied to use new query method." if filter_terms.nil?

      groupby_dimension = @app.dimensions[header1]
      raise "Invalid groupby dimension '#{header1}'." if groupby_dimension.nil?

      @sql = QuerySummaryRunning.new(@app, self, groupby_dimension, interval, start_date, end_date, transactions, site_constraint, filter_terms).query_string
    else
      <<-SQL
        select * 
        from summary_running(
          '#{fact_table()}',
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
  end
  
  def summary_running(header1, interval, start_date, end_date, transactions,  site_constraint, filter_xml)
    @sql = summary_running_sql(header1, interval, start_date, end_date, transactions, site_constraint, filter_xml)
    ex(@sql)
  end
  
  def detail_sql(header1, filter_column, start_date, end_date, transactions,  site_constraint, filter_xml, filter_terms = nil)

    site_date = 
      if site_constraint == 'end'
        end_date
      elsif site_constraint == 'start' 
        start_date
      else
        ''
      end

    # If the filter column given is one of the 'static columns' (as per the static_cols() method) then
    # use the static friendly detail query. Otherwise use the regular friendly detail query.
    sql = 
      if static_cols().include?(filter_column)
        site_date_for_query = 
          if @app.use_new_query_generation_method?
            if site_date == ''
              nil
            else
              site_date
            end
          else
            if site_date == ''
              'NULL'
            else
              "'#{site_date}'"
            end
          end

        member_date = filter_column.include?('start') ? start_date : (end_date+1)
        
        filter_column = filter_column.sub('_start_count', '').sub('_end_count', '')

        if @app.use_new_query_generation_method?
          raise "FilterTerms instance must be supplied to use new query method." if filter_terms.nil?

          groupby_dimension = @app.dimensions[header1]
          raise "Invalid groupby dimension '#{header1}'." if groupby_dimension.nil?

          QueryDetailStaticFriendly.new(@app, self, groupby_dimension, filter_column, member_date, site_date_for_query, filter_terms).query_string 
        else
          <<-SQL 
	        select * 
  	      from detail_static_friendly(
    	      '#{fact_table()}',
      	    '#{header1}', 
        	  '#{filter_column}',  
          	'#{member_date}',
          	#{site_date_for_query},
          	'#{filter_xml}'
         	 )
      	SQL
        end
      else
        if @app.use_new_query_generation_method?()
          raise "FilterTerms instance must be supplied to use new query method." if filter_terms.nil?

          groupby_dimension = @app.dimensions[header1]
          raise "Invalid groupby dimension '#{header1}'." if groupby_dimension.nil?

          QueryDetailFriendly.new(@app, self, groupby_dimension, start_date, end_date, transactions, site_constraint, filter_column, filter_terms).query_string 
        else
          <<-SQL 
            select * 
            from detail_friendly(
              '#{fact_table()}',
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
      end
    
    sql
  end
  
  def detail(header1, filter_column, start_date, end_date, transactions,  site_constraint, filter_xml)
    @sql = detail_sql(header1, filter_column, start_date, end_date, transactions,  site_constraint, filter_xml)
    ex(@sql)
  end
  
  def transfer_sql(start_date, end_date, site_constraint, filter_xml, filter_terms = nil)
    
    sql = <<-SQL
      select
        changedate
        , sum(a1p_other_gain + paying_other_gain) transfer_in
        , sum(-a1p_other_loss - paying_other_loss) transfer_out
        from
    SQL

    sql << if @app.use_new_query_generation_method?()
      raise "FilterTerms instance must be supplied to use new query method." if filter_terms.nil?

      groupby_dimension = @app.dimensions.dimension_for_id_mandatory('status')

      detail_friendly_sql = QueryDetailFriendly.new(@app, self, groupby_dimension, start_date, end_date, false, site_constraint, '', filter_terms).query_string 
      "(#{detail_friendly_sql}) as detail_friendly"
    else
      <<-SQL
          detail_friendly(
            '#{fact_table()}',
            'status',
            '',
            '#{start_date.strftime(DateFormatDB)}',
            '#{(end_date+1).strftime(DateFormatDB)}',
            false,
            '#{site_constraint}',
            '#{filter_xml}'
          )
      SQL
    end

    sql << <<-SQL
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
  
  def get_transfers(start_date, end_date, site_constraint, filter_xml, filter_terms = nil)
    @sql = transfer_sql(start_date, end_date, site_constraint, filter_xml, filter_terms)
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
      val = ex(get_display_text_sql(column,id))
      
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
  
  @@cache_file = 'tmp/cache.Marshal'
  @@cache_status = "Not in use."
  @@mtime = Time.parse('1900-01-01')
  
  def self.cache_status
    @@cache_status
  end
  
  def self.cache_status=(status)
    @@cache_status = status
  end
  
  def self.mtime
    mtime = Time.parse('1900-01-01')
    begin
      mtime = File.mtime(@@cache_file)
    rescue
      # file doesn't exist or couldn't be read
    end
    mtime
  end
  
  def self.cache
    if !defined? @@cache
      load_cache
    else
      # reload if the modification date is greater (because it was updated by another server)
      if @@mtime < mtime
        @@cache_status += "cache has been updated. "
        load_cache
      end
    end
    
    @@cache
  end
  
  def initialize(app)
    # The data is initialised every request but in production the cache should persist
    # as a static (class) singleton. Cache status is reset at the start of the page 
    # life when db class is instantiated
    ChurnDBDiskCache.cache_status = "" 
    @app = app
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

     # dbeswick: add a 'num_tuples' method to the cache results, so code that relies on the
     # pgruby interface will continue to work.
     def result.num_tuples
       length()
     end

     result
   end
   
private
  
  def self.load_cache
      begin
        data = ""
        File.open(@@cache_file, 'r') do |f|
          while line=f.gets
            data+=line
          end
          
          @@mtime = File.mtime(@@cache_file) # set modification time, so we can tell if we need to reload
        end
            
        @@cache = Marshal::load(data)
        ChurnDBDiskCache.cache_status += "cache reloaded. "
      rescue
        @@cache = Hash.new
        #throw "failed to load cache"
        ChurnDBDiskCache.cache_status += "failed to load cache. "
      end
  end
  
  def self.update_cache(sql, result)
    filename = ChurnDBDiskCache.cache[sql]
    
    # if we aren't replacing a missing file, a new key will be appended to the hash, 
    # so the size of the hash will map to the index of this new value which will
    # be new, so use this index as a unique file name (works as long as the no keys 
    # are removed)
    filename = "tmp/cache-#{self.cache.size.to_s}.Marshal" if filename.nil? 
    
    begin 
      #write data to file - only if data file write succeeds will index file be updated
      File.open(filename, 'w') do |f|
        f.puts Marshal::dump(result)
        
        #update index
        @@cache[sql] = filename 
        File.open(@@cache_file, 'w') do |f|
          f.puts Marshal::dump(@@cache)
        end
        
        @@mtime = File.mtime(@@cache_file) # set modification time, so we can tell if we need to reload
      end
    
    rescue
      ChurnDBDiskCache.cache_status += "Failed to write to cache. Deleting cached data in case of inconsistency."
      # remove cache file, so whatever ended up in the index gets reloaded next time
      begin
        File.delete(filename)
      rescue
        # ignore deletion error because I'm reasonably confident it won't cause a problem
      end
    end
  end
    
    
  
end

