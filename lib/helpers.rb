module Churnobyl
  module Helpers
    def query_string
      URI.parse(request.url).query
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
      URI.escape "#{Filter}[#{@defaults['group_by']}]=#{row_header_id}&#{FilterNames}[#{row_header_id}]=#{row_header}"
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

      URI.escape "group_by=#{hash[defaults['group_by']]}"
    end

    def filter_names
      params[FilterNames] || []
    end
    
  end
end