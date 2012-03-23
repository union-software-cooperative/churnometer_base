
module Support
  def validate_params
    # @uri when constructing html links - it is better than request.url because we can remove parameters that don't pass validation
    # do a bunch of replacements to simplify swapping url parameters with search and replace 
    @uri= request.url.gsub('+', ' ').gsub('%20', ' ').gsub(' =','=').gsub('= ', '')
    
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
    startdb = Date.parse((db.ex data_sql.getdimstart_sql)[0]['getdimstart'])+1
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
      @uri = @uri.sub("startDate=#{params['startDate']}", "startDate=#{startDate.strftime(DateFormatDisplay)}")
      params['startDate'] = startDate.strftime(DateFormatDisplay)
    end
    if (!params['endDate'].nil? || !params['intervalEnd'].nil?)
      @uri = @uri.sub("endDate=#{params['endDate']}", "endDate=#{endDate.strftime(DateFormatDisplay)}")
      params['endDate'] = endDate.strftime(DateFormatDisplay)
    end
    # I don't know what these global values are for
    @start = startDate
    @end = endDate
    
    if (params['group_by']!='companyid' &&  !(params['site_constrain'] == '' || params['site_constrain'].nil?))
      @uri = @uri.gsub("site_constrain=#{params['site_constrain']}", '')
      @uri = @uri.gsub('&&', '&')
      params['site_constrain'] = ''
      warning +="WARNING:  Disabled site constraint because it only makes sense when grouping by Work Site <br/>"
    end
    
    #warning +=h @uri
    
    warning
  end

  def data_to_excel(data)
    @data = DataPresenter.new data
    book = Spreadsheet::Excel::Workbook.new
    sheet = book.create_worksheet
  
    if @data.has_data?
    
      #Get column list
      if params['table'].nil?
        cols = @data[0]
      elsif summary_tables.include?(params['table'])
          cols = summary_tables[params['table']]
      else
        cols = ['memberid'] | member_tables[params['table']]  
      end
    
      # Add header
      merge_cols(@data[0], cols).each_with_index do |hash, x|
        sheet[0, x] = col_names[hash.first] || hash.first
      end
  
      # Add data
      @data.each_with_index do |row, y|
        merge_cols(row, cols).each_with_index do |hash,x|
        
          if filter_columns.include?(hash.first) 
            sheet[y + 1, x] = hash.last.to_i
          else
              sheet[y + 1, x] = hash.last
          end  
      
        end
      end
    end
  
    path = "tmp/data.xls"
    book.write path
  
    send_file(path, :disposition => 'attachment', :filename => File.basename(path))
  end
  
end