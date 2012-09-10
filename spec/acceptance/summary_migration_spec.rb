require './lib/churn_db'
require './lib/query/query_summary'
require './lib/settings'
 
include Settings

class Authorize
  def leader?
    true
  end
end

class ChurnDB
  def database_config_key
    'database_regression'
  end
end

db = ChurnDB.new

# Pass 'is_leader' and 'is_admin' true to get the full set of groups
groups = group_names(true, true).keys

describe "'Summary' function Ruby migration" do
  groups.product([false, true]).each do |group, with_trans|
    transactions_descriptor =
      if with_trans
        'transactions enabled'
      else
        'transactions disabled'
      end

    it "should return results matching the SQL summary function with group '#{group}', #{transactions_descriptor}." do
      header1 = group
      start_date = Time.new('1900-01-01')
      end_date = Time.new('2012-09-07')
      site_constraint = ''
      filter = '<search><status>1</status><status>14</status><status>11</status></search>'
      with_trans = false
      
      result_sqlfunc = db.summary(header1, 
                                  start_date, 
                                  end_date, 
                                  with_trans, 
                                  site_constraint, 
                                  filter)
      
      query = QuerySummary.new(db, 
                               header1, 
                               start_date, 
                               end_date, 
                               with_trans, 
                               site_constraint, 
                               filter)
      
      result_rubyfunc = query.execute
      
      sql_result = result_sqlfunc.to_a.collect{ |hash| hash.to_a}
      ruby_result = result_rubyfunc.to_a.collect{ |hash| hash.to_a}
      
      ruby_result.should eq(sql_result)
    end
  end
end
