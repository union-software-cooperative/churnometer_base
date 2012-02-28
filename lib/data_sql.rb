class DataSql
  attr_reader :params

  def initialize(params)
    @params = params
  end
  
  def summary_sql(leader)
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
                            #{leader.to_s}, 
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
                            #{leader.to_s}, 
                            '#{xml}'
                            )
      SQL
    end
  end
  
  def member_sql(leader)
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
                              #{leader.to_s}, 
                              '#{xml}'
                              )
      SQL
    end
    
    sql
  end
  
  
  def getdimstart_sql
    <<-SQL
      select getdimstart('#{(query['group_by'] || 'branchid')}')
    SQL
  end

  def growth(data) 
    start_date = Date.parse(query['startDate'])
    end_date = Date.parse(query['endDate'])
  
    start_count = paying_start_total(data)
    
    started = 0
    data.each { | row | started += row['paying_real_gain'].to_i }
    
    stopped = 0
    data.each { | row | stopped += row['paying_real_loss'].to_i }
    
    end_count = start_count + stopped + started
    
    start_date == end_date || start_count == 0 ? Float(1/0.0) : Float((((Float(end_count) / Float(start_count)) **  (365.0/(Float(end_date - start_date)))) - 1) * 100).round(1)
  end

  def series_count(data)
    rows = data.group_by{ |row| row['row_header1'] }.count
  end

  def get_cards_in_growth_target(data)
    
    # the number of people who stopped paying
    stopped = 0
    data.each { | row | stopped -= row['paying_real_loss'].to_i }
    
    # count the people who start paying without giving us a card
    # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
    resume = 0 
    data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 
    
    # count of a1p people who start paying
    conversions = 0
    data.each { | row | conversions -= row['a1p_to_paying'].to_i }
    
    # count the joiners who fail to convert to paying
    failed = 0 
    data.each { | row | failed -= row['a1p_to_other'].to_i }
    
    # count the joiners who fail to convert to paying
    cards = 0 
    data.each { | row | cards += row['a1p_real_gain'].to_i }
    
    start_date = Date.parse(query['startDate'])
    end_date = Date.parse(query['endDate'])
    
    cards_per_week = 0.0
    if start_date != end_date  
      growth = Float((paying_start_total(data) + paying_transfers_total(data))) * 0.1 / 365 * Float(end_date - start_date) # very crude growth calculation - But I don't think CAGR makes sense, the formula would be # growth = (((10% + 1) ^ (duration/365) * start) - start) 
       
      # METHOD 1.  for every sign up, we only convert some to paying
      # growth = conversions == 0 || cards == 0 ? growth : growth * (cards/conversions) # if we got no conversions or cards, then don't worry about the ratio and just go for cards in - bad bad bad.
      
      # METHOD 2. For every card we get in, there is some that never start paying 10 vs 2.  If we get 20 we'd expect 4 to not start paying.
      # To get the 4 we multiple growth target number failed/cards * target + target 
      # growth += (cards == 0 ? 0 : failed/cards * growth)  
      
      # METHOD 3.  Maybe I'm counting the conversion ratio twice in Method 1 and 2.  
      # The conversion ratio may be already included in the cards we need to hold our ground
      # See + failed in equation below, so I should leave the raw growth figure alone
      # Method 1 and 2 also leave the equation vulnerable to crazy volatility
       
      # to hold our ground we need to recruit the same number as those that stopped, 
      # less those that historically resume paying on their own (these are freebies)
      # plus those that new cards that failed to start paying
      # plus a certain amount to acheive some growth figure.  The growth figure should reflect
      cards_per_week = Float((Float(stopped - resume + failed + growth) / Float(end_date - start_date) * 7 )).round(1) 
    end
    
    cards_per_week
  end

  def get_cards_in_target(data)
    
    # the number of people who stopped paying
    stopped = 0
    data.each { | row | stopped -= row['paying_real_loss'].to_i }
    
    # count the people who start paying without giving us a card
    # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
    resume = 0 
    data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 
    
    # count the joiners who fail to convert to paying
    failed = 0 
    data.each { | row | failed -= row['a1p_to_other'].to_i }
    
    start_date = Date.parse(query['startDate'])
    end_date = Date.parse(query['endDate'])
    
    cards_per_week = 0.0
    if start_date != end_date  
      cards_per_week = Float((Float(stopped - resume + failed) / Float(end_date - start_date) * 7 )).round(1)
    end
    
    cards_per_week
  end

  def get_cards_in(data)
    
    # the number of people who stopped paying
    cards = 0
    data.each { | row | cards += row['a1p_real_gain'].to_i }
    
    start_date = Date.parse(query['startDate'])
    end_date = Date.parse(query['endDate'])
    
    cards_per_week = 0.0
    if start_date != end_date  
      cards_per_week = Float(((cards) / Float(end_date - start_date) * 7 )).round(1)
    end
    
    cards_per_week
  end
  
  def get_display_text_sql(column, id)
    <<-SQL
      select displaytext from displaytext where attribute = '#{column}' and id = '#{id}' limit 1
    SQL
  end
  
  def periods(data)
    data.group_by{ |row| row['period_header'] }.sort{|a,b| a[0] <=> b[0] }
  end
  
  def pivot(data, next_group_by)
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
            
  private

  def paying_start_total(data)
    # can't figure out enumerable way to sum this
    t=0
    data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[0]['paying_start_count'].to_i
    end
    t
  end

  def paying_transfers_total(data)
    t=0
    data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[0] ['paying_other_gain'].to_i + v[0] ['paying_other_loss'].to_i
    end
    t
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
            
  def locks
    (params['lock'] || []).reject{ |column_name, value | value.empty? }
  end
  
  def static_cols
    [
      'a1p_end_count',
      'a1p_start_count',
      'paying_end_count',
      'paying_start_count'
    ]
  end
  
  
end
