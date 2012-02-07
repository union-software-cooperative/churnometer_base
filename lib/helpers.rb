module Churnobyl
  module Helpers
    def has_data?
      @data && @data.count > 0
    end
    
    def query_string
      URI.parse(request.url).query
    end

    def fix_date_params
      if !params['startDate'].nil?
        @start = Date.parse((db.ex getdimstart_sql)[0]['getdimstart'])+1
        if @start > Date.parse(params['startDate'])
          @warning = 'WARNING: Adjusted start date to when we first started tracking ' + (params['group_by'] || 'branchid') + ' (you had selected ' + params['startDate'] + ')' 
          params['startDate'] = @start.to_s
        end
      end

      if !params['endDate'].nil?
        @end = Date.parse(params['endDate'])
        if DateTime.now < @end
          @end = Time.now
        end
        params['endDate'] = @end.strftime("%Y-%m-%d")
      end
    end

    def show_col?(column_name)
      result=true
      if params['adv'] == '1'
        result=true
      elsif params['column'].to_s == ''
        result=simple_summary.include?(column_name)
      else
        result=simple_member.include?(column_name)
      end
      result
    end

    def getdimstart(dim)
       @data = db.ex(dimstart_sql)
    end

    def drill_down_link(row)
      uri_join_queries drill_down(row), next_group_by
    end
    
    def uri_join_queries(*queries)
      if params == {}
        request.url + '?' + queries.join('&')
      else
        request.url + '&' + queries.join('&')
      end
    end
    
    def export_cell(row, column_name)
      row_filter = "#{Filter}[#{(params['group_by'] || 'branchid')}]=#{row['row_header1_id']}"
      
      export_column(column_name) + "&" + row_filter
    end
    
    def detail_cell(row, column_name)
      row_filter = "#{Filter}[#{(params['group_by'] || 'branchid')}]=#{row['row_header1_id']}"
      row_filter_name = "#{FilterNames}[#{row['row_header1_id']}]=#{row['row_header1']}"

      detail_column(column_name) + "&" + row_filter + "&" + row_filter_name
    end
    
    def export_column(column_name)
      column_filter = "column=#{column_name}"
      
      "/export_member_details?#{query_string}&#{column_filter}"
    end
    
    def detail_column(column_name)
      column_filter = "column=#{column_name}"
      
      "/?#{query_string}&#{column_filter}"
    end
 
     def can_detail_cell?(column_name, value)
      (
        %w{a1p_real_gain a1p_real_loss a1p_other_gain a1p_other_loss paying_real_gain paying_real_loss paying_other_gain paying_other_loss other_other_gain other_other_loss}.include? column_name
      ) && (value.to_i != 0 && value.to_i.abs < 100)
    end

    def can_export_cell?(column_name, value)
      (
        %w{a1p_real_gain a1p_real_loss a1p_other_gain a1p_other_loss paying_real_gain paying_real_loss paying_other_gain paying_other_loss other_other_gain other_other_loss}.include? column_name
      ) && (value.to_i != 0)
    end

    def groups_by_collection
      [
        ["branchid", "Branch"],
        ["lead", "Lead Organizer"],
        ["org", "Organizer"],
        ["areaid", "Area"],
        ["companyid", "Work Site"],
        ["industryid", "Industry"],
        ["del", "Delegate Training"],
        ["hsr", "HSR Training"],
        ["nuwelectorate", "Electorate"],
        ["state", "State"],
        ["feegroup", "Fee Group"]
      ]
    end
    
    def simple_summary
      [
        'row_header',
        'row_header1',
        'row_header2',
        'a1p_real_gain',
        'paying_start_count',
        'paying_real_gain',
        'paying_real_loss',
        'paying_end_count',
        'contributors', 
        'posted'
      ]
    end

    def simple_member
      [
        'row_header',
        'row_header1',
        'row_header2',
        'member',
        'oldstatus',
        'newstatus',
        'oldcompany',
        'newcompany'
      ]
    end
      
    def no_total
      [
        'row_header',
        'row_header_id',
        'row_header1',
        'row_header1_id',
        'row_header2',
        'row_header2_id',
        'contributors', 
        'annualisedavgcontribution'
      ]
    end
   
    def drill_down(row)
      row_header1_id = row['row_header1_id']
      row_header1 = row['row_header1']
      URI.escape "#{Filter}[#{@query['group_by']}]=#{row_header1_id}&#{FilterNames}[#{row_header1_id}]=#{row_header1}"
    end

    def next_group_by
      hash = {
        'branchid'      => 'lead',
        'lead'          => 'org',
        'org'           => 'companyid',
        'state'         => 'areaid',
        'area'          => 'companyid',
        'feegroup'      => 'companyid',
        'nuwelectorate' => 'org',
        'del'           => 'companyid',
        'hsr'           => 'companyid',
        'industryid'	=> 'companyid',
	'companyid'     => 'companyid'
      }

      URI.escape "group_by=#{hash[query['group_by']]}"
    end

    def filter_names
      params[FilterNames] || []
    end
    
    def remove_filter_link(filter_value)
      f = params[Filter].reject { |field, value| value == filter_value }
      fn = params[FilterNames].reject { |value, name| value == filter_value }
      p = params
      p[Filter] = f
      p[FilterNames] = fn
      
      temp = Addressable::URI.new
      temp.query_values = p
      
      uri = URI.parse(request.url)
      uri.query = temp.query
      uri.to_s
    end
    
    def safe_add(a, b)
      if (a =~ /\$/) || (b =~ /\$/ )
        a.to_money + b.to_money
      else
        a.to_i + b.to_i
      end
    end
  end
end
