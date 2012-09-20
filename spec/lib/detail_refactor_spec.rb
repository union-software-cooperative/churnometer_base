require './lib/churn_db'
require './lib/churn_request'
require './spec/lib/sql_ruby_refactor_testruns'

class SQLRubyRefactorTestRunsDetail < SQLRubyRefactorTestRuns
  class TestRunDetail < TestRun
    attr_reader :filter_column
    
    def initialize(option_tuple, query_class)
      super(option_tuple)
      @filter_column = option_tuple[5]
      @query_class = query_class
    end

    def to_s
      "filter column '#{@filter_column}', #{super}"
    end
  end

  attr_reader :query_class
  
  def initialize(query_class, limit = nil, random_seed = nil)
    super(limit, random_seed)
    @query_class = query_class
  end

  def filter_options
    [[{"status"=>[1,14,11],"branchid"=>'b1'}, 'simple filter'],
     [{"status"=>[1,14,11],"branchid"=>['-b1','b2'],"lead"=>'l2',"org"=>'!o7'}, 'complex filter']]
  end

  def groups
    ['branchid',
    'lead']
  end

  def testrun_class
    TestRunDetail
  end

  def make_testrun(option_tuple)
    testrun_class().new(option_tuple, @query_class)
  end

  def options_for_combination
    valid_filter_columns = @query_class.filter_column_to_where_clause.keys
    super + [ valid_filter_columns ]
  end
end

def execute_testrun(testruns, input_proc, test_run)
  test_run.start

  input_tuple = input_proc.call(testruns, test_run)
  sql_text = input_tuple.first
  query = input_tuple.last
  
  t1 = Thread.new{ 
    testruns.db(0).ex_async(sql_text).to_a.collect{ |hash| hash.to_a }.sort
  }
  
  t2 = Thread.new{ 
    query.execute_async.to_a.collect{ |hash| hash.to_a }.sort
  }

  ruby_result = t1.value
  sql_result = t2.value

  if ruby_result != sql_result
    puts query.query_string
  end
  
  [ruby_result, sql_result]
end

describe "'detail_static' function Ruby refactoring" do
  sql_proc = proc do |testruns, test_run|
    site_date = 
      if test_run.site_constraint == 'end' 
        test_run.date_end
      elsif test_run.site_constraint == 'start' 
        test_run.date_start
      else
        nil
      end
    
    sql = <<-SQL 
        select * 
        from detail_static(
        	'#{testruns.db(0).fact_table()}',
        	'#{test_run.group}', 
        	'#{test_run.filter_column}',
        	#{testruns.db(0).db.sql_date(test_run.date_end)},
          #{site_date.nil? ? 'NULL' : testruns.db(0).db.sql_date(site_date)},
        	'#{ChurnRequest.filter_xml(test_run.filter, [])}'
          )
      SQL


    query = testruns.query_class.new(testruns.db(1), 
                                     test_run.group,
                                     test_run.filter_column,
                                     test_run.date_end,
                                     site_date, 
                                     QueryFilterTerms.from_request_params(test_run.filter))
    
    [sql, query]
  end

  testruns = SQLRubyRefactorTestRunsDetail.new(QueryDetailStatic)

  testruns.each do |test_run|
    it "should return results matching the SQL detail function with #{test_run}" do
      ruby_result, sql_result = execute_testrun(testruns, sql_proc, test_run)
      ruby_result.should eq(sql_result)
    end
  end
end

describe "'detail_friendly' function Ruby refactoring" do
  sql_proc = proc do |testruns, test_run|
    sql = <<-SQL 
        select * 
        from detail_friendly(
        '#{testruns.db(0).fact_table()}',
        '#{test_run.group}', 
        '#{test_run.filter_column}',
        #{testruns.db(0).db.sql_date(test_run.date_start)},
        #{testruns.db(0).db.sql_date(test_run.date_end + 1)},
        #{test_run.with_trans},
        '#{test_run.site_constraint}',
        '#{ChurnRequest.filter_xml(test_run.filter, [])}'
          )
      SQL

    query = testruns.query_class.new(testruns.db(1), 
                                     test_run.group,
                                     test_run.date_start,
                                     test_run.date_end,
                                     test_run.with_trans, 
                                     test_run.site_constraint, 
                                     test_run.filter_column,
                                     QueryFilterTerms.from_request_params(test_run.filter))
    
    [sql, query]
  end

  # Use 'seed' to reproduce failing test results.
  # This query is slow, so only test 100 combinations of parameters.
  # The "better than nothing" approach to regression testing.
  seed = nil
  testruns = SQLRubyRefactorTestRunsDetail.new(QueryDetailFriendly, 100, seed)

  testruns.each do |test_run|
    it "should return results matching the SQL detail function with #{test_run}" do
      ruby_result, sql_result = execute_testrun(testruns, sql_proc, test_run)
      ruby_result.should eq(sql_result)
    end
  end
end

describe "'detail' function Ruby refactoring" do
  sql_proc = proc do |testruns, test_run|
    sql = <<-SQL
      select * 
      from detail(
        '#{testruns.db(0).fact_table()}',
        '#{test_run.group}', 
        '#{test_run.filter_column}',
        #{testruns.db(0).db.sql_date(test_run.date_start)},
        #{testruns.db(0).db.sql_date(test_run.date_end + 1)},
        #{test_run.with_trans},
        '#{test_run.site_constraint}',
        '#{ChurnRequest.filter_xml(test_run.filter, [])}'
        )
    SQL

    query = testruns.query_class.new(testruns.db(1), 
                                     test_run.group,
                                     test_run.date_start,
                                     test_run.date_end,
                                     test_run.with_trans, 
                                     test_run.site_constraint, 
                                     test_run.filter_column,
                                     QueryFilterTerms.from_request_params(test_run.filter))
    
    [sql, query]
  end

  testruns = SQLRubyRefactorTestRunsDetail.new(QueryDetail)

  testruns.each do |test_run|
    it "should return results matching the SQL detail function with #{test_run}" do
      ruby_result, sql_result = execute_testrun(testruns, sql_proc, test_run)
      ruby_result.should eq(sql_result)
    end
  end
end
