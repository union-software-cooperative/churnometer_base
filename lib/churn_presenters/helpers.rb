require 'spreadsheet'

module ChurnPresenter_Helpers
  
  include Rack::Utils
  alias_method :h, :escape_html # needed for build_url - refactor
  
  
  # common totals
  
  def paying_start_total
    # group_by is used so only the first row of running total is summed
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[0]['paying_start_count'].to_i
    end
    t
  end

  def paying_end_total
    # group_by is used so only the first row of running totals is summed
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[v.count-1]['paying_end_count'].to_i
    end
    t
  end
  
  def paying_transfers_total
    # group_by is used so only the first row of running totals is summed
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[0]['paying_other_gain'].to_i + v[0]['paying_other_loss'].to_i
    end
    t
  end

  
  
  # common drill downs
  
  def can_detail_cell?(column_name, value)
    (
      filter_columns.include? column_name
    ) && (value.to_i != 0 && value.to_i.abs < MaxMemberList)
  end

  def can_export_cell?(column_name, value)
    (
      filter_columns.include? column_name
    ) && (value.to_i != 0)
  end
  
  def drill_down_header(row)
    {
      "#{Filter}[#{@request.params['group_by'] || 'branchid'}]" => row['row_header1_id'], 
      "group_by" => next_group_by[@request.params['group_by']]
    }
  end   
  
  def drill_down_interval(row)
    drill_down_header(row)
      .merge!(
        {
          'startDate' => row['period_start'], 
          'endDate' => row['period_end']
        }
      )
  end
  
  def drill_down_cell(row, column_name)
    (@request.params['interval'] == 'none' ? drill_down_header(row) : drill_down_interval(row))
      .merge!( 
        { 
          'column' => column_name,
          "group_by" => @request.params['group_by'] # this prevents the change to the group by option
        } 
      )
  end
  
  def drill_down_footer(column_name)
    { 
      'column' => column_name
    } 
  end
  
  
  def build_url(query_hashes)
    #TODO refactor out params if possible, or put this function somewhere better, with params maybe
    
    # build uri from params - rejecting filters & lock because they need special treatment
    query = @request.params.reject{ |k,v| v.empty? }.reject{ |k, v| k == Filter}.reject{ |k, v| k == "lock"}
    
    # flatten filters, rejecting status - TODO get rid of status
    (@request.params[Filter] || {}).reject{ |k,v| v.empty? }.reject{ |k,v| k == 'status'}.each do |k, v|
      query["#{Filter}[#{k}]"] = v
    end
    
    # flatten lock
    (@request.params["lock"] || {}).reject{ |k,v| v.empty? }.each do |k, v|
      query["lock[#{k}]"] = v
    end
    
    # merge new items
    query.merge! (query_hashes || {})
    
    # remove any empty/blanked-out items
    query = query.reject{ |k,v| v.nil? }
    
    # make uri string
    uri = '/?'
    query.each do |key, value|
      uri += "&#{h key}=#{h value}" 
    end
    
    uri.sub('/?&', '?')
  end
  
  def format_date(date)
    if date.nil? || date == '1900-01-01'
      ''
    else
      Date.parse(date).strftime(DateFormatDisplay)
    end
  end
  
  # exporting - expects an array of hash
  def excel(data)
     # todo refactor this and ChurnPresenter_table.to_excel - consider common table format
     book = Spreadsheet::Excel::Workbook.new
     sheet = book.create_worksheet

     # Add header
     data[0].each_with_index do |hash, x|
       sheet[0, x] = (col_names[hash.first] || hash.first)
     end

     # Add data
     data.each_with_index do |row, y|
       row.each_with_index do |hash,x|
         if filter_columns.include?(hash.last) 
           sheet[y + 1, x] = hash.last.to_f
         else
           sheet[y + 1, x] = hash.last
         end  
       end
     end

     path = "tmp/data.xls"
     book.write path

     path
   end
  
end



