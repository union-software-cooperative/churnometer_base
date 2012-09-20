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
  
  include Settings
  
  def db
    @db ||= ChurnDB.new
  end
  
  def initialize(url, query_string, auth, params, churndb = nil)
    # interpret request
    @url = url
    @query_string = query_string
    @auth = auth
    @params = query_defaults.rmerge(params)
    @db = churndb
    @warnings = validate_params(@params)
    
    # set private members
    @header1 = @params['group_by'].to_s
    @interval = @params['interval'].to_s
    @filter_column = @params['column'].to_s
    @export_type = @params['export'].to_s
    @start_date = Date.parse(@params['startDate'])
    @end_date = Date.parse(@params['endDate'])
    @transactions = auth.leader?
    @site_constraint = @params['site_constraint'].to_s
    @xml = self.class.filter_xml parsed_params()[Filter], locks(@params['lock'])
      
    # load data and public members
    @type = :summary if @filter_column == ''
    @type = :detail if @filter_column != '' or @export_type=='detail'

    @query_filterterms = 
      if use_new_query_generation_method()
        QueryFilterTerms.from_request_params(parsed_params()[Filter])
      else
        nil
      end

    @sql = case @type
    when :summary
      if @interval == 'none'
        db.summary_sql(@header1, @start_date, @end_date, @transactions, @site_constraint, @xml, @query_filterterms)  
      else
        db.summary_running_sql(@header1, @interval, @start_date, @end_date, @transactions, @site_constraint, @xml)  
      end
    when :detail
      db.detail_sql(@header1, @filter_column, @start_date, @end_date, @transactions, @site_constraint, @xml, @query_filterterms)
    else
      raise "Cannot load data - unknown query type (#{@type.to_s})"
    end
    
    @data = db.ex(@sql)
    @cache_hit = db.cache_hit
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

  def get_transfers
    db.get_transfers(@start_date, @end_date, @site_constraint, @xml, @query_filterterms)
  end
  
  def data_entry_view?
    @header1 == 'statusstaffid' || @params[Filter].reject { |k,v| v.empty? }.has_key?('statusstaffid')
  end

  private

  def validate_params(params)
    warning = ''

      # override date filters with interval filters
    startDate = nil;
    endDate = nil;
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
      startDate = EarliestStartDate
    end

    if endDate.nil?
      endDate = Date.today
    end

    # make sure startDate isn't before data began
    startdb = Date.parse((db.getdimstart(params['group_by']))[0]['getdimstart'])+1
    if startdb > startDate
      startDate = startdb
      warning += 'WARNING: Adjusted start date to when we first started tracking ' + (params['group_by'] || 'branchid') + ' (you had selected ' + params['startDate'] + ')<br/>'
    end

    # make sure endDate isn't in the future or before startDate
    if Date.today < endDate
      endDate = Date.today
      warning += 'WARNING: Adjusted end date to today (you had selected ' + params['endDate'] + ') <br/>'
    end

    if Date.today < startDate
      startDate = Date.today
      warning += 'WARNING: Adjusted start date to today (you had selected ' + params['startDate'] + ')<br/>'
    end

    if startDate > endDate
      endDate = startDate
      warning += "WARNING: Adjusted end date to #{endDate.strftime(DateFormatDisplay)} (you had selected #{ params['endDate'] })<br/>"
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

    if (params['group_by']!='companyid' &&  !(params['site_constraint'] == '' || params['site_constraint'].nil?))
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

    locks.each do | k, csv|
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
            
  def locks(lock)
    (lock || []).reject{ |column_name, value | value.empty? }
  end
  
end
