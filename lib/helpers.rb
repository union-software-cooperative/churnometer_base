module Churnobyl
  module Helpers
    def has_data?
      @data && @data.count > 0
    end
    
    def query_string
      URI.parse(request.url).query
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
      row_filter = "#{Filter}[#{params['group_by']}]=#{row['row_header_id']}"
      
      export_column(column_name) + "&" + row_filter
    end
    
    def export_column(column_name)
      column_filter = "column=#{column_name}"
      
      "/export_member_details?#{query_string}&#{column_filter}"
    end
    
    def can_export_cell?(column_name, value)
      (value.to_i != 0) && (
        %w{a1p_gain a1p_loss paying_gain paying_loss other_gain other_loss}.include? column_name
      )
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

    def drill_down(row)
      row_header_id = row['row_header_id']
      row_header = row['row_header']
      URI.escape "#{Filter}[#{@query['group_by']}]=#{row_header_id}&#{FilterNames}[#{row_header_id}]=#{row_header}"
    end

    def next_group_by
      hash = {
        'branchid'      => 'lead',
        'lead'          => 'org',
        'org'           => 'companyid',
        'state'         => 'area',
        'area'          => 'companyid',
        'feegroup'      => 'companyid',
        'nuwelectorate' => 'org',
        'del'           => 'companyid',
        'hsr'           => 'companyid',
        'companyid'     => 'companyid'
      }

      URI.escape "group_by=#{hash[query['group_by']]}"
    end

    def filter_names
      params[FilterNames] || []
    end
    
  end
end