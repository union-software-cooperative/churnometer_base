module Churnobyl
  module DataSql
    def defaults
      {
        'group_by' => 'branchid',
        'startDate' => '2011-10-6',
        'endDate' => '2012-1-3',
        Filter => {
          'status' => [1, 14]      
        }
      }.rmerge(params)
    end

    def member_sql
      xml = filter_xml defaults[Filter]

        <<-SQL 
      select * 

      from churndetailfriendly3('#{defaults['group_by']}', 
                            '',  
                            '#{defaults['startDate']}', 
                            '#{defaults['endDate']}',
                            true, 
                            '#{xml}'
                            )
        SQL
    end

    def summary_sql  
      xml = filter_xml defaults[Filter]

      <<-SQL 
    select * 

    from churnsummarydyn9('#{defaults['group_by']}', 
                          '#{defaults['startDate']}', 
                          '#{defaults['endDate']}',
                          true, 
                          '#{xml}'
                          )
      SQL
    end

    def filter_xml(filters)
      # Example XML
      # <search><branchid>NG</branchid><org>dpegg</org><status>1</status><status>14</status></search>
      result = "<search>"
      filters.each do |k, v|
        if v.is_a?(Array)
          v.each do |item|
            result += "<#{k}>#{item}</#{k}>"
          end
        else
          result += "<#{k}>#{v}</#{k}>"
        end
      end

      result += "</search>"
      result
    end
    
  end
end
