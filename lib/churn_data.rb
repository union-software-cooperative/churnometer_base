class Db
  def initialize
    @conn = PGconn.open(
      :host =>      Config['database']['host'],
      :port =>      Config['database']['port'],
      :dbname =>    Config['database']['dbname'],
      :user =>      Config['database']['user'],
      :password =>  Config['database']['password']
    )
  end
  
  def ex(sql)
    @conn.exec(sql)
  end
end


class ChurnDB
  attr_reader :db
  attr_reader :params
  
  def initialize()
  end
  
  def db
    @db ||= Db.new
  end
  
  def ex(sql)
    db.ex(sql)
  end  
  
  def summary_sql(params, leader)
    xml = filter_xml params[Filter], locks(params['lock'])
    start_date = (Date.parse(params['startDate'])).strftime(DateFormatDB)
    end_date = (Date.parse(params['endDate'])+1).strftime(DateFormatDB)


    if params['interval'] == 'none'
      <<-SQL
      select * 
      from summary(
                            'memberfacthelper4',
                            '#{params['group_by']}', 
                            '',
                            '#{start_date}',
                            '#{end_date}',
                            #{leader.to_s}, 
                            '#{params['site_constrain']}',
                            '#{xml}'
                            )
      SQL
    else
      <<-SQL
      select * 
      from summary_running(
                            'memberfacthelper4',
                            '#{params['group_by']}', 
                            '#{params['interval']}', 
                            '#{start_date}',
                            '#{end_date}',
                            #{leader.to_s}, 
                            '#{params['site_constrain']}',
                            '#{xml}'
                            )
      SQL
    end
  end
  
  def summary(params, leader)
    db.ex(summary_sql(params, leader))
  end
  
  def member_sql(params, transactionsOn)
    xml = filter_xml params[Filter], locks(params['lock'])

    start_date = (Date.parse(params['startDate'])).strftime(DateFormatDB)
    end_date = (Date.parse(params['endDate'])+1).strftime(DateFormatDB)
    
    if static_cols.include?(params['column'])
    
      member_date = params['column'].include?('start') ? start_date : end_date
      site_date = ''
      if params['site_constrain'] == 'end' 
        site_date = end_date
      end
      if params['site_constrain'] == 'start' 
        site_date = start_date
      end
      
      filter_column = params['column'].sub('_start_count', '').sub('_end_count', '')
    
      sql = <<-SQL 
        select * 
        from detail_static_friendly(
                              'memberfacthelper4',
                              '#{params['group_by']}', 
                              '#{filter_column}',  
                              '#{member_date}',
                              #{site_date == '' ? 'NULL' : "'#{site_date}'"},
                              '#{xml}'
                            )
      SQL
    else
      sql = <<-SQL 
        select * 
        from detail_friendly(
                              'memberfacthelper4',
                              '#{params['group_by']}', 
                              '#{params['column']}',  
                              '#{start_date}',
                              '#{end_date}',
                              #{transactionsOn.to_s}, 
                              '#{params['site_constrain']}',
                              '#{xml}'
                              )
      SQL
    end
    
    sql
  end
  
  def detail(params, leader)
    db.ex(member_sql(params, leader))
  end
  
  def sites_at_date(params, leader)
    xml = filter_xml params[Filter], locks(params['lock'])

    start_date = (Date.parse(params['startDate'])).strftime(DateFormatDB)
    end_date = (Date.parse(params['endDate'])+1).strftime(DateFormatDB)
    dte = params['site_constrain'] == 'end' ? end_date : start_date
    
    sql = <<-SQL 
      select * 
      from sites_at_date(
                          'memberfacthelper4',
                          '#{params['group_by']}', 
                          '',
                          '#{dte}',
                          #{leader.to_s}, 
                          '#{xml}'
                          )
    SQL
  end
  
  def transfer_sql(params)
    xml = filter_xml params[Filter], locks(params['lock'])
    start_date = (Date.parse(params['startDate'])).strftime(DateFormatDB)
    end_date = (Date.parse(params['endDate'])+1).strftime(DateFormatDB)


    sql = <<-SQL
      select
        changedate
        , sum(a1p_other_gain + paying_other_gain) transfer_in
        , sum(-a1p_other_loss - paying_other_loss) transfer_out
        from
          detail_friendly(
            'memberfacthelper4',
            'status',
            '',
            '#{start_date}',
            '#{end_date}',
            false,
            '#{params['site_constrain']}',
            '#{xml}'
          )
        where
          paying_other_gain <> 0
          or paying_other_loss <> 0
          or a1p_other_gain <> 0
          or a1p_other_loss <> 0
        group by
          changedate
        order by
          changedate
    SQL

    sql
  end
  
  def get_transfers(params)
    db.ex(transfer_sql(params))
  end

  def getdimstart_sql(group_by)
    # TODO refactor default group_by branchid
    <<-SQL
      select getdimstart('#{(group_by || 'branchid')}') 
    SQL
  end
  
  def getdimstart(group_by)
    db.ex(getdimstart_sql(group_by))
  end

  def get_display_text_sql(column, id)
     <<-SQL
       select displaytext from displaytext where attribute = '#{column}' and id = '#{id}' limit 1
     SQL
  end
  
  def get_display_text(column, id)
    t = "error!"
    
    if id == "unassigned" 
      t = "unassigned"
    else
      val = db.ex(get_display_text_sql(column,id))
      
      if val.count != 0 
        t = val[0]['displaytext']
      end
    end 
    
    t
  end

  private

  def filter_xml(filters, locks)
    # Example XML
    # <search><branchid>NG</branchid><org>dpegg</org><status>1</status><status>14</status><status>11</status></search>
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
            
  def locks(lock)
    (lock || []).reject{ |column_name, value | value.empty? }
  end
  
  def static_cols
    [
      'a1p_end_count',
      'a1p_start_count',
      'paying_end_count',
      'paying_start_count',
      'stopped_start_count',
      'stopped_end_count'
    ]
  end

end
