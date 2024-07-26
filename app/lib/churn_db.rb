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
require 'time'
require 'pg'

# This class should abstract database calls at as high a level as possible.
# Currently, the target database is postgresql.
class Db
  attr_reader :host
  attr_reader :dbname
  attr_reader :user
  attr_reader :pass

  def initialize(churn_app)
    element = churn_app.config.get_mandatory('database')
    element.ensure_hashkey('host')
    element.ensure_hashkey('port')
    element.ensure_hashkey('dbname')
    element.ensure_hashkey('user')
    element.ensure_hashkey('password')

    @host = element['host'].value
    @dbname = element['dbname'].value
    @user = element['user'].value
    @pass = element['password'].value

    @conn = PGconn.open(
      :host =>      @host,
      :port =>      element['port'].value,
      :dbname =>    @dbname,
      :user =>      @user,
      :password =>  @pass
    )

    # ensure_app_state_table() # TODO Why isn't this created in db manager
  end

  def close_db
    @conn.finish() if !@conn.nil?
    @conn = nil
  end

  def transaction(&block)
    @conn.transaction(&block)
  end

  def process_query_result(query_result)
    # dbeswick: add a 'length' method to the sql results, so code that relies on the array returned
    # from the sql disk cache will continue to work.
    if !query_result.respond_to?(:length)
      def query_result.length
        num_tuples()
      end
    end

    query_result
   end

  def ex(sql)
    process_query_result(@conn.exec(sql))
  end

  def async_ex(sql)
    process_query_result(@conn.async_exec(sql))
  end

  # Quotes a string or boolean as appropriate for insertion into an SQL query string.
  # dbeswick tbd: add a method that will quote any data type where possible.
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
  # A type must be supplied if an empty array is given, or an exception is raised.
  def sql_array(array, type=nil)
    raise "PostgreSQL requires empty arrays to have an explicit type when creating an empty array. You must supply a type." if array.empty? && type.nil?

    result = "ARRAY[#{array.collect{ |x| quote(x) }.join(', ')}]"
    result << "::#{type}[]" if type
    result
  end

  # Returns a comma separated, quoted list of elements suitable for use in an SQL
  # 'where <column> in' clause.
  # Doesn't include surrounding brackets.
  # Will raise an exception if an empty array is given, as IN clauses always require at least one
  # element.
  # Example: "select * from table where id in ( #{sql_in(my_array)} )"
  # dbeswick tbd: support other data types such as DateTime objects.
  def sql_in(array)
    raise "Empty arrays can't be used as input to an SQL WHERE IN clause. IN clauses always require at least one value to be supplied." if array.empty?
    array.collect { |element| quote(element) }.join(",")
  end

  # Returns the date portion of the given ruby Time object, formatted appropriately for use in a
  # query string.
  def sql_date(time)
    quote(time.strftime(DateFormatDB))
  end

  # Writes a piece of application state to the database. 'value' is converted to a string.
  def set_app_state(key, value)
    result = ex("update appstate set value = #{quote(value)} where key = #{quote(key)}")

    if result.cmd_tuples == 0
      ex("insert into appstate (key, value) values (#{quote(key)}, #{quote(value)})")
    end
  end

  # Returns nil if no state has yet been defined for the given key.
  def get_app_state(key)
    result = ex("select value from appstate where key = #{quote(key)}")
    if result.ntuples == 0
      nil
    else
      result.values[0][0]
    end
  end

protected
  def ensure_app_state_table
    sql = <<-SQL
      create table if not exists appstate (key varchar, value varchar)
    SQL

    ex(sql)
  end
end


class ChurnDB
  include Settings

  attr_reader :db
  attr_reader :params
  attr_reader :sql
  attr_reader :cache_hit

  def host
    db.host
  end

  def dbname
    db.dbname
  end

  def user
    db.user
  end

  def pass
    db.pass
  end

  def initialize(app)
    @app = app
  end

  def db
    @db ||= Db.new(@app)
  end

  def close_db
    @db.close_db() if !@db.nil?
    @db = nil
  end

  def transaction(&block)
    @db.transaction(&block)
  end

  def ex(sql)
    @cache_hit = false
    db.ex(sql)
  end

  def ex_async(sql)
    @cache_hit = false
    db.async_ex(sql)
  end

  def fact_table
    @fact_table ||= @app.memberfacthelper_table
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
        , sum(external_gain) transfer_in
        , sum(-external_loss) transfer_out
      from
    SQL

    sql << if @app.use_new_query_generation_method?()
      raise "FilterTerms instance must be supplied to use new query method." if filter_terms.nil?

      groupby_dimension = @app.dimensions.dimension_for_id_mandatory('status')

      detail_friendly_sql = QueryDetailFriendly.new(@app, self, groupby_dimension, start_date, end_date, false, site_constraint, '', filter_terms).query_string
      "(#{detail_friendly_sql}) as detail_friendly "
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
        external_gain <> 0
        or external_loss <> 0
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
    if group_by.nil?
      group_by = @app.groupby_default_dimension.id
    end

    <<-SQL
      select startdate getdimstart, coalesce(enddate, current_date) getdimfinish from dimstart where dimension = '#{group_by}'
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

  def get_display_text(dimension, id)
    raise "A Dimension instance must be supplied." if !dimension.kind_of?(Dimension)
    t = "#{id} !"

    if id == "unassigned"
      t = "unassigned"
    else
      val = ex(get_display_text_sql(dimension.column_base_name, id))

      if val.count != 0
        t = val[0]['displaytext']
      end
    end

    t
  end

  private

  def static_cols
    [
      'paying_start_count',
      'stopped_start_count',
      'a1p_start_count',
      'waiver_start_count',
      'member_start_count',
      'nonpaying_start_count',
      'green_start_count',
      'orange_start_count',
      'paying_end_count',
      'stopped_end_count',
      'a1p_end_count',
      'waiver_end_count',
      'member_end_count',
      'nonpaying_end_count',
      'green_end_count',
      'orange_end_count'
    ]
  end

end

class ChurnDBDiskCache < ChurnDB
  def self.cache_status
    @@cache_status
  end

  def self.cache_status=(status)
    @@cache_status = status
  end

  def initialize(app)
    # The data is initialised every request but in production the cache should persist
    # as a static (class) singleton. Cache status is reset at the start of the page
    # life when db class is instantiated
    ChurnDBDiskCache.cache_status = ""
    @app = app
  end

  def ex(sql)
    filename = ChurnDBDiskCache.cache_file(sql)

    result = nil
    # CACHE HIT
    if File.exists?(filename)
      @cache_hit = true
      ChurnDBDiskCache.cache_status += "cache hit (#{filename}). "

      result = Marshal::load(File.read(filename))
    # CACHE MISS
    else
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
    end

    # dbeswick: add a 'num_tuples' method to the cache results, so code that relies on the
    # pgruby interface will continue to work.
    # tbd: forbid the use of num_tuples, and instead always use length. pgruby result classes should
    # provide a 'length' reader.
    def result.num_tuples
      length()
    end

    result
  end

  ## CACHE REGENERATION IS UNUSED AS OF OCTOBER 2020.
  ## A rebuild of regeneration logic should store the original sql in the cache
  ## files so it can be re-run.
  ## Each cache file should also timestamp the last cache hit so we can age out
  ## cache files that go unused for X amount of time. (Probably a week.)

  private
  def self.cache_file(sql)
    "tmp/cache-#{Digest::MD5.hexdigest(sql)}.Marshal"
  end

  def self.update_cache(sql, result)
    filename = ChurnDBDiskCache.cache_file(sql)

    begin
      #write data to file - only if data file write succeeds will index file be updated
      File.open(filename, 'w') do |f|
        f.puts Marshal::dump(result)
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
