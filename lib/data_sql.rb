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
        },
      }.rmerge(params)
    
    end

    def member_sql
      xml = filter_xml query[Filter], locks
      
      end_date = (Date.parse(query['endDate'])+1).strftime("%Y-%m-%d")
      
      if static_cols.include?(query['column'])
        if query['column'].include?('start')
          end_date = (Date.parse(query['startDate'])+1).strftime("%Y-%m-%d")
        end
        
        filter_column = query['column'].sub('_start_count', '').sub('_end_count', '')
        
        sql = <<-SQL 
          select * 
          from staticdetailfriendly20(
                                'memberfacthelperpaying2',
                                '#{query['group_by']}', 
                                '#{filter_column}',  
                                '#{end_date}',
                                '#{xml}'
                              )
          SQL
      else
        sql = <<-SQL 
          select * 
          from churndetailfriendly20(
                                'memberfacthelperpaying2',
                                '#{query['group_by']}', 
                                '#{query['column']}',  
                                '#{query['startDate']}', 
                                '#{end_date}',
                                #{leader?.to_s}, 
                                '#{xml}'
                                )
        SQL
      end
      
      sql
    end

    def summary_sql  
      xml = filter_xml query[Filter], locks

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

    def get_display_text_sql(column, id)
        <<-SQL
          select displaytext from displaytext where attribute = '#{column}' and id = '#{id}' limit 1
        SQL
    end

    def periods(data)
        # data.each do |row|
        #           row.each do |column_name, v|
        #             if column_name == 'period_header'
        data.group_by{ |row| row['period_header'] }.sort{|a,b| a[0] <=> b[0] }
    end
    
    def pivot(data)
      series = Hash.new
      
      rows = data.group_by{ |row| row['row_header1'] }
      rows.each do | row |
        series[row[0]] = Array.new
        periods(data).each do | period |
          intersection = row[1].find { | r | r['period_header'] == period[0] }
          if intersection.nil? 
            series[row[0]] << "{ y: null }"
          else
            series[row[0]] << "{ y: #{intersection['running_paying_net'] }, id:'&intervalStart=#{intersection['period_start']}&intervalEnd=#{intersection['period_end']}&interval=none&f[#{(query['group_by'] || 'branchid')}]=#{intersection['row_header1_id']}&#{next_group_by}' }"
          end
        end
      end
    
      series
    end
    
    # def pivot(data)
    #   series = Hash.new
    #   
    #   rows = data.group_by{ |row| row['row_header1'] }
    #   rows.each do | row |
    #     series[row[0]] = Array.new
    #     periods(data).each do | period |
    #       intersection = row[1].find { | r | r['period_header'] == period[0] }
    #       if intersection.nil? 
    #         series[row[0]] << 'null'
    #       else
    #         series[row[0]] << intersection['running_paying_net'] 
    #       end
    #     end
    #   end
    # 
    #   series
    # end
    # 
    
    def series_count(data)
      rows = data.group_by{ |row| row['row_header1'] }.count
    end

    def paying_start_total(data)
      # can't figure out enumerable way to sume this
      t=0
      data.each do | row |
        t += row['paying_start_count'].to_i
      end
      t
    end

    def paying_end_total(data)
      t=0
      data.each do | row |
        t += row['paying_end_count'].to_i
      end
      t
    end
    
    def filter_xml_node(k,v)
      case v[0]
        when '!' 
          "<not_#{k}>#{v.sub('!','')}</not_#{k}>" 
        when '-' 
          "<ignore_#{k}>#{v.sub('!','')}</ignore_#{k}>" 
        else 
          "<#{k}>#{v}</#{k}>"
        end
    end
    

    def filter_xml(filters, locks)
      # Example XML
      # <search><branchid>NG</branchid><org>dpegg</org><status>1</status><status>14</status></search>
      result = "<search>"
      filters.each do |k, v|
        if v.is_a?(Array)
          v.each do |item|
            result += filter_xml_node(k,item)
          end
        else
          result += filter_xml_node(k,v)
        end
      end

      locks.each do | k, csv|
        csv.split(',').each do | item |
          result += filter_xml_node(k,item)
        end
      end
      
      result += "</search>"
      result
    end
    
  end
end
