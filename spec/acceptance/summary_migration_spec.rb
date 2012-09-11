require './lib/churn_db'
require './lib/query/query_summary'
require './lib/settings'

db = ChurnDB.new
def db.database_config_key
  'database_regression'
end

describe "'Summary' function Ruby migration" do
  # A class to clearly define and express the data being tested in each run in all combinations.
  class TestRuns
    include Settings

    class TestRun
      attr_accessor :group
      attr_accessor :with_trans
      attr_accessor :site_constraint

      def to_s
        transactions_descriptor =
          if @with_trans
            'transactions enabled'
          else
            'transactions disabled'
          end

        site_constraint_descriptor =
          if @site_constraint.empty?
            'no site constraint'
          else
            "site constraint '#{@site_constraint}'"
          end

        "group '#{group}', #{transactions_descriptor}, #{site_constraint_descriptor}"
      end
    end

    def initialize
      # Pass 'is_leader' and 'is_admin' true to get the full set of groups
      groups = group_names(true, true).keys

      transaction_options = [true, false]
      site_constraint_options = ['', 'start', 'end']
      
      @test_option_combinations = groups.product(transaction_options, site_constraint_options).collect do |tuple|
        t = TestRun.new
        t.group = tuple[0]
        t.with_trans = tuple[1]
        t.site_constraint = tuple[2]
        t
      end
    end

    def each(&block)
      @test_option_combinations.each(&block)
    end
  end

  def self.test_migration_for_dates(db, start_date, end_date, date_range_description)
    # Run for all groups, with and without transactions and site constraints.
    TestRuns.new.each do |test_run|
      it "should return results matching the SQL summary function with #{test_run}, and with dates #{date_range_description}." do
        header1 = test_run.group
        site_constraint = test_run.site_constraint
        filter = '<search><status>1</status><status>14</status><status>11</status></search>'
        with_trans = test_run.with_trans
        
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

  test_migration_for_dates(db, Time.new('1900-01-01'), Time.new('2012-09-07'), "from the beginning of data to some time in the future")

  test_migration_for_dates(db, Time.new('2012-05-01'), Time.new('2012-09-07'), "from quite some time after the beginning of data to a short time afterwards")
end
