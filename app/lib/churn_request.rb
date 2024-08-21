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
require './lib/query/query_summary'
require 'cgi'

class ChurnRequest
  attr_reader :url
  attr_reader :params
  attr_reader :warnings
  attr_reader :type
  attr_reader :sql
  attr_reader :auth
  attr_reader :data
  attr_reader :cache_hit
  attr_reader :xml
  attr_reader :query_filterterms
  attr_reader :interval

  include Settings

  def db
    @db
  end

  def close_db
    @db.close_db()
  end

  def initialize(url, query_string, auth, params, app, churndb)
    # interpret request
    @app = app
    @url = url
    @query_string = query_string
    @auth = auth
    @params = query_defaults.rmerge(params)
    @db = churndb

    # set private members
    @header1 = @params['group_by'].to_s
    @interval = @params['interval'].to_s
    @filter_column = @params['column'].to_s
    @export_type = @params['export'].to_s
    @period = @params['period'].to_s
    if @period!='custom'
      @params['startDate'] = period_start(@period).strftime(DateFormatDisplay)
      @params['endDate'] = period_end(@period).strftime(DateFormatDisplay)
    end

    @warnings = validate_params(@params)

    @start_date = Date.parse(@params['startDate'])
    @end_date = Date.parse(@params['endDate'])

    @transactions = auth.role.allow_transactions?
    @site_constraint = @params['site_constraint'].to_s
    @xml = self.class.filter_xml parsed_params()[Filter], locks(@params['lock'])

    # load data and public members
    @type = :summary if @filter_column == ''
    @type = :detail if @filter_column != '' or @export_type=='detail'

    @query_filterterms =
      if @app.use_new_query_generation_method?()
        FilterTerms.from_request_params(parsed_params()[Filter], locks(@params['lock']), @app.dimensions)
      else
        nil
      end

    @sql = case @type
    when :summary
      if @interval == 'none'
        db.summary_sql(@header1, @start_date, @end_date, @transactions, @site_constraint, @xml, @query_filterterms)
      else
        db.summary_running_sql(@header1, @interval, @start_date, @end_date, @transactions, @site_constraint, @xml, @query_filterterms)
      end
    when :detail
      db.detail_sql(@header1, @filter_column, @start_date, @end_date, @transactions, @site_constraint, @xml, @query_filterterms)
    else
      raise "Cannot load data - unknown query type (#{@type.to_s})"
    end


    @data = db.ex(@sql)
    @warnings += cross_check(@data)
    @cache_hit = db.cache_hit
  end

  def period_start(period)
    case period
    when "today"
      Date.today
    when "yesterday"
      Date.today - 1
    when "this_week"
      Date.today - Date.today.wday
    when "last_week"
      Date.today - Date.today.wday - 7
    when "this_month"
      Date.today - Date.today.mday + 1
    when "last_month"
      (Date.today - Date.today.mday) - (Date.today - Date.today.mday).mday + 1 # cumbersome???
    when "this_year"
      Date.new(Date.today.year, 1, 1)
    when "last_year"
      Date.new(Date.today.year - 1, 1 , 1)
    end
  end

  def period_end(period)
  case period
    when "today"
      Date.today
    when "yesterday"
      Date.today - 1
    when "this_week"
      Date.today
    when "last_week"
      Date.today - Date.today.wday - 1
    when "this_month"
      Date.today
    when "last_month"
      Date.today - Date.today.mday
    when "this_year"
      Date.today
    when "last_year"
      Date.new(Date.today.year - 1, 12, 31)
    end
  end


  def has_data?
    @data && @data.count > 0
  end

  def cross_check(data)
    warning = ""
    if has_data? && @type == :summary
      data.each do |row|
        if row['cross_check'] != ""
          warning += "#{row['cross_check']} cross check failed for #{row['row_header1']}<br\>"
        end
      end
    end
    warning
  end

  # When multiple parameters of the same name are passed in the query string, Sinatra only uses the last
  # one. To fix that, this method mirrors Sinatra's usual parsing but also makes arrays from
  # duplicate parameter keys in the query string.
  #
  # Also, query parameters in the format "param_name!text[key]=value" have the "!text" portion removed,
  # i.e. "parsed_params()[key1][key2] == value" for query string "?key1!discarded[key2]=value".
  # This functionality is currently used when displaying filters. See comments in form.erb.
  #
  # tbd: make all code use this method, replace "params" method with this method.
  def parsed_params
    @parsed_params ||=
      begin
        result = {}

        CGI::parse(@query_string).each do |key, val|
          # Expand arrays that have only one element
          val = if val.length == 1
            val.first
          else
            val
          end

          # Handle parameters that should be encoded in a hash, of the format "?param_name[key]=value".

          # Extract param_name and key, and strip "!text" from the param_name.
          match = /^([^\[!]+)(?:[^\[]*)\[([^\]]+)\]/.match(key)
           is_hash_param = !match.nil?

          if is_hash_param
            param_name = match[1]
            param_key_name = match[2]

            hash = result[param_name] ||= {}

            # If the parameter is already in the hash, create an array, otherwise just set
            # the value. This handles duplicate instances of hash format parameters in the
            # query string.
            if hash.has_key?(param_key_name)
              hash[param_key_name] = Array(hash[param_key_name]) + [val]
            else
              # 'val' may be an array or a single element, but this code gives the proper
              # result in both cases.
              hash[param_key_name] = val
            end
          else
            # The value is not a hash format value, so just set it as normal.
            result[key] = val
          end
        end

        query_defaults.rmerge(result)
      end
  end

  # Returns a Dimension instance.
  def groupby_dimension
    if params['group_by'].nil? || params['group_by'].empty?
      @app.groupby_default_dimension
    else
      param_dimension = @app.dimensions[params['group_by']]

      if param_dimension
        param_dimension
      else
        raise "No such groupby dimension '#{params['group_by']}'"
      end
    end
  end

  def groupby_column_id
    groupby_dimension().id.downcase
  end

  def groupby_column_name
    groupby_dimension().name.downcase
  end

  def get_transfers
    db.get_transfers(@start_date, @end_date, @site_constraint, @xml, @query_filterterms)
  end

  private

  def validate_params(params)
    warning = ''

      # override date filters with interval filters
    startDate = nil
    endDate = nil

    if !params['startDate'].nil?
      startDate = Date.parse(params['startDate'])
    end
    if !params['endDate'].nil?
      endDate = Date.parse(params['endDate'])
    end
    if !params['intervalStart'].nil?
      startDate = Date.parse(params['intervalStart'] )
    end
    if !params['intervalEnd'].nil?
      endDate = Date.parse(params['intervalEnd'])
    end

    if startDate.nil?
      startDate = app.application_start_date
    end

    if endDate.nil?
      endDate = Date.today
    end

    # make sure startDate isn't before data began
    dim_start_id = @app.dimensions[params['group_by']].column_base_name
    dim_start_result = db.getdimstart(dim_start_id)

    if dim_start_result.nil? || dim_start_result.num_tuples == 0 || dim_start_result[0]['getdimstart'].nil?
      raise "Couldn't find an entry in the 'dimstart' table for the groupby dimension '#{params['group_by']}' (column is '#{dim_start_id}')"
    end

    enddb = Date.parse(dim_start_result[0]['getdimfinish'])
    over_upper_bound_text = enddb < Date.today ? "after we ended tracking of #{groupby_column_id()}" : "needlessly far in the future"
    start_selection = "You had selected #{params['startDate']}."
    end_selection = "You had selected #{params['endDate']}."

    # Cases we need to correct for:
    # 1a. Period start or b. end before dimstartdate
    # 2a. Period start or b. end after dimenddate
    # 3. Period end before period start (or inverse)
    # 4. Period start [too far] in the future - nothing bad will happen, just trying to save people from themselves??

    # (2a, 4)
    if startDate > enddb
      startDate = enddb
      warning += "WARNING: Adjusted start date to #{startDate.strftime(DateFormatDisplay)}, as it was #{over_upper_bound_text}. #{start_selection}<br/>"
    end

    # (2b)
    if endDate > enddb
      endDate = enddb
      warning += "WARNING: Adjusted end date to #{endDate.strftime(DateFormatDisplay)}, as it was #{over_upper_bound_text}. #{end_selection}<br/>"
    end

    # (1a)
    if startDate < (startdb = Date.parse(dim_start_result[0]['getdimstart'])+1)
      startDate = startdb
      warning += "WARNING: Adjusted start date to #{startDate.strftime(DateFormatDisplay)}, as it was before we started tracking #{groupby_column_id()}. #{start_selection}<br/>"
    end

    # (1b, 3)
    if endDate < startDate
      endDate = startDate
      warning += "WARNING: Adjusted end date to #{endDate.strftime(DateFormatDisplay)}, as it was before the start date. #{end_selection}<br/>"
    end

    if (!params['startDate'].nil? || !params['intervalStart'].nil?)
      params['startDate'] = startDate.strftime(DateFormatDisplay)
    end
    if (!params['endDate'].nil? || !params['intervalEnd'].nil?)
      params['endDate'] = endDate.strftime(DateFormatDisplay)
    end
    # I don't know what these global values are for
    @start = startDate
    @end = endDate

    if (params['group_by']!=@app.config['work_site_dimension_id'] &&  !(params['site_constraint'] == '' || params['site_constraint'].nil?))
      params['site_constraint'] = ''
      warning +="WARNING:  Disabled site constraint because it only makes sense when grouping by Work Site <br/>"
    end

    warning
  end

  def self.filter_xml(filters, locks)
    # Example XML
    # <search><branchid>NG</branchid><org>dpegg</org><status>1</status><status>14</status><status>11</status></search>
    result = "<search>"
    filters.each do |k, v|
      if v.is_a?(Array)
        v.each do |item|
          result += filter_xml_node(k,item)
        end
      else
        result += filter_xml_node(k,v)
      end
    end

    locks.each do |k, csv|
      csv.split(',').each do | item |
        result += filter_xml_node(k,item)
      end
    end

    result += "</search>"
    result
  end

  def self.filter_xml_node(k,v)
    case v[0]
      when '!'
        "<not_#{k}>#{v.sub('!','')}</not_#{k}>"
      when '-'
        "<ignore_#{k}>#{v.sub('!','')}</ignore_#{k}>"
      else
        "<#{k}>#{v}</#{k}>"
      end
  end

  # lock[companyid]= comes through as {"companyid"=>""}
  # lock[companyid] comes through as {"companyid"=>nil}
  # Outlook strips the = sign off the end of links!
  # Fix with (value || "")
  def locks(lock)
    (lock || []).reject{ |column_name, value| (value || "").empty? }
  end
end
