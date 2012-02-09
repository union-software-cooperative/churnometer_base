module Churnobyl
  module DataSql
    def query
      {
        'group_by' => 'branchid',
        'startDate' => '2011-8-14',
        'endDate' => Time.now.strftime("%Y-%m-%d"),
        'column' => '',
        'interval' => 'none',
        Filter => {
          'status' => [1, 14]      
        }
      }.rmerge(params)
    
    end

    def member_sql
      xml = filter_xml query[Filter]
      
        <<-SQL 
      select * 
      from churndetailfriendly10('#{query['group_by']}', 
                            '#{query['column']}',  
                            '#{query['startDate']}', 
                            '#{(Date.parse(query['endDate'])+1).strftime("%Y-%m-%d")}',
                            #{leader?.to_s}, 
                            '#{xml}'
                            )
        SQL
    end

    def summary_sql  
      xml = filter_xml query[Filter]

      if query['interval'] == 'none'
        <<-SQL
        select * 
        from churnsummarydyn19(
                              'memberfacthelperpaying2',
                              '#{query['group_by']}', 
                              '',
                              '#{query['startDate']}', 
                              '#{(Date.parse(query['endDate'])+1).strftime("%Y-%m-%d")}',
                              #{leader?.to_s}, 
                              '#{xml}'
                              )
        SQL
      else
        <<-SQL
        select * 
        from churnrunningdyn19(
                              'memberfacthelperpaying2',
                              '#{query['group_by']}', 
                              '#{query['interval']}', 
                              '#{query['startDate']}', 
                              '#{(Date.parse(query['endDate'])+1).strftime("%Y-%m-%d")}',
                              #{leader?.to_s}, 
                              '#{xml}'
                              )
        SQL
      end
    end

    def getdimstart_sql
      <<-SQL
        select getdimstart('#{(query['group_by'] || 'branchid')}')
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
