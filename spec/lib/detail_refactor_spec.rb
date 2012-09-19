require './lib/churn_db'
require './lib/churn_request'
require './lib/query/query_detail'
require './spec/lib/sql_ruby_refactor_testruns'

db1 = ChurnDB.new
def db1.database_config_key
  'database_regression'
end

db2 = ChurnDB.new
def db2.database_config_key
  'database_regression'
end

class SQLRubyRefactorTestRunsDetail < SQLRubyRefactorTestRuns
  class TestRunDetail < TestRun
    attr_reader :filter_column
    
    def initialize(option_tuple)
      super
      @filter_column = option_tuple[5]
    end

    def to_s
      "filter column #{@filter_column}, #{super}"
    end
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

  def options_for_combination
    valid_filter_columns = QueryDetail.filter_column_to_where_clause.keys
    super + [ valid_filter_columns ]
  end
end

describe "'Detail' function Ruby refactoring" do
  def self.test_migration(db1, db2)
    # Run for all groups, with and without transactions and site constraints.
    SQLRubyRefactorTestRunsDetail.new.each do |test_run|
      it "should return results matching the SQL detail function with #{test_run}" do
        detail_sql = <<-SQL
      select * 
      from detail(
        '#{db1.fact_table()}',
        '#{test_run.group}', 
        '#{test_run.filter_column}',
        #{db1.db.sql_date(test_run.date_start)},
        #{db1.db.sql_date(test_run.date_end + 1)},
        #{test_run.with_trans},
        '#{test_run.site_constraint}',
        '#{ChurnRequest.filter_xml(test_run.filter, [])}'
        )
    SQL

        t1 = Thread.new{ 
          db1.ex_async(detail_sql).to_a.collect{ |hash| hash.to_a }
        }.run
        
        query = QueryDetail.new(db2, 
                                test_run.group,
                                test_run.date_start,
                                test_run.date_end,
                                test_run.with_trans, 
                                test_run.site_constraint, 
                                test_run.filter_column,
                                QueryFilterTerms.from_request_params(test_run.filter))

        t2 = Thread.new{ 
          query.execute_async.to_a.collect{ |hash| hash.to_a }
        }.run

        ruby_result = t1.value
        sql_result = t2.value

        if ruby_result != sql_result
          puts query.query_string
        end
        
        ruby_result.should eq(sql_result)
      end
    end
  end

  test_migration(db1, db2)
end
