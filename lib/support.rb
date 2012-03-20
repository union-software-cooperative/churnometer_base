module Support
  def fix_date_params
    @warning = ''  # this needs to go before the controller, not here

    if params['startDate'].nil?
      params['startDate'] = EarliestStartDate.strftime(DateFormatDisplay)
    end

    if params['endDate'].nil?
      params['endDate'] = Date.today.strftime(DateFormatDisplay)
    end

      # override date filters with interval filters
    if !params['intervalStart'].nil?
      params['startDate'] = params['intervalStart'] 
    end
    
    if !params['intervalEnd'].nil? 
      params['endDate'] = params['intervalEnd']
    end
    
    # make sure startDate isn't before data began
    @start = Date.parse((db.ex data_sql.getdimstart_sql)[0]['getdimstart'])+1
    if @start > Date.parse(params['startDate'])
      @warning += 'WARNING: Adjusted start date to when we first started tracking ' + (params['group_by'] || 'branchid') + ' (you had selected ' + params['startDate'] + ')<br/>'
      params['startDate'] = @start.to_s
    end

    # make sure endDate isn't in the future or before startDate
    @start = Date.parse(params['startDate'])
    @end = Date.parse(params['endDate'])

    if Date.today < @end
      @end = Date.today
      @warning += 'WARNING: Adjusted end date to today (you had selected ' + params['endDate'] + ') <br/>'
    end

    if Date.today < @start
      @start = Date.today
      @warning += 'WARNING: Adjusted start date to today (you had selected ' + params['startDate'] + ')<br/>'
    end

    if @start > @end
      @end = @start
      @warning += "WARNING: Adjusted end date to #{@end.strftime(DateFormatDisplay)} (you had selected #{ params['endDate'] })<br/>"
    end

    params['startDate'] = @start.strftime(DateFormatDisplay)
    params['endDate'] = @end.strftime(DateFormatDisplay)

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