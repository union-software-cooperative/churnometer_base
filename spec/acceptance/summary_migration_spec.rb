require './lib/churn_db'
require './lib/query/query_summary'

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

describe "'Summary' function Ruby migration" do
  it "should return results matching the SQL summary function." do
    header1 = 'branchid'
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

    sql_result_yaml = result_sqlfunc.to_a.collect{ |hash| hash.to_a}
    ruby_result_yaml = result_rubyfunc.to_a.collect{ |hash| hash.to_a}

    ruby_result_yaml.should eq(sql_result_yaml)
  end
end
