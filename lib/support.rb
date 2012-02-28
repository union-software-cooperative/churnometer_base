module Support
  def fix_date_params
    # override date filters with interval filters
    if !params['intervalStart'].nil?
      params['startDate'] = params['intervalStart'] 
    end
    
    if !params['intervalEnd'].nil? 
      params['endDate'] = params['intervalEnd']
    end
    
    # make sure startDate isn't before data began
    if !params['startDate'].nil?
      @start = Date.parse((db.ex data_sql.getdimstart_sql)[0]['getdimstart'])+1
      if @start > Date.parse(params['startDate'])
        @warning = 'WARNING: Adjusted start date to when we first started tracking ' + (params['group_by'] || 'branchid') + ' (you had selected ' + params['startDate'] + ')' 
        params['startDate'] = @start.to_s
      end
    end

    # make sure endDate is in the future
    if !params['endDate'].nil?
      @end = Date.parse(params['endDate'])
      if DateTime.now < @end
        @end = Time.now
      end
      params['endDate'] = @end.strftime("%Y-%m-%d")
    end
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