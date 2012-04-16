class ChurnRequest

  attr_reader :url
  attr_reader :params
  attr_reader :warnings
  attr_reader :type
  attr_reader :sql
  attr_reader :auth
  attr_reader :data
  
  include Mappings
  
  def db
    @db ||= ChurnDB.new
  end
  
  def initialize(url, auth, params)
    # setup request
    @url = url
    @auth = auth
    @params = query_defaults.rmerge(params)
    @warnings = validate_params(@params)
    @type = @params['column'].empty? ? :summary : :detail
    
    # load request
    @sql = db.summary_sql(@params, auth.leader?) if @type == :summary 
    @sql = db.detail(@params, auth.leader?) if @type == :detail
    
    @data = db.ex(@sql)
  end


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

    if (params['group_by']!='companyid' &&  !(params['site_constrain'] == '' || params['site_constrain'].nil?))
      params['site_constrain'] = ''
      warning +="WARNING:  Disabled site constraint because it only makes sense when grouping by Work Site <br/>"
    end

    warning
  end
end