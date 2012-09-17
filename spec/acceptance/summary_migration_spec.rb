require './lib/churn_db'
require './lib/churn_request'
require './lib/query/query_summary'
require './lib/settings'

Dir["./lib/query/*.rb"].each { |f| require f }

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
      attr_accessor :filter
      attr_accessor :filter_description
      attr_accessor :query_class

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
        
        "group '#{group}', #{transactions_descriptor}, #{site_constraint_descriptor}, #{filter_description}"
      end
    end

    def initialize
      # Pass 'is_leader' and 'is_admin' true to get the full set of groups
      groups = group_names(true, true).keys
      
      transaction_options = [true, false]
      site_constraint_options = ['', 'start', 'end']
      
      # the tuples here are [filter xml, filter description]
      filter_options = 
        [[{"status"=>[1,14,11]}, 'no filter'],
         [{"status"=>[1,14,11],"branchid"=>'b1'}, 'simple filter'],
         [{"status"=>[1,14,11],"branchid"=>['-b1','b2'],"lead"=>'l2',"org"=>'!o7'}, 'complex filter'],
         [{"status"=>[1,14,11],'branchid'=>'b2','lead'=>'!l2','statusstaffid'=>'d2'}, 'complex filter with statusstaffid term']
        ]
      
      options_for_combination = 
        [
         groups,
         transaction_options,
         site_constraint_options,
         filter_options
        ]
      
      # Make test runs for all combinations of the option groups given above. 
      @test_option_combinations = options_for_combination.first.product(*options_for_combination[1..-1]).collect do |tuple|
        t = TestRun.new
        
        t.group = tuple[0]
        t.with_trans = tuple[1]
        t.site_constraint = tuple[2]
        
        t.filter = tuple[3].first
        t.filter_description = tuple[3].last
        
        t.query_class = query_class_for_group(t.group)
        
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
        filter = test_run.filter
        with_trans = test_run.with_trans
        
        result_sqlfunc = db.summary(header1, 
                                    start_date, 
                                    end_date, 
                                    with_trans, 
                                    site_constraint, 
                                    ChurnRequest.filter_xml(filter, []))
        
        query = test_run.query_class.new(db, 
                                         header1, 
                                         start_date, 
                                         end_date, 
                                         with_trans, 
                                         site_constraint, 
                                         filter)
        
        result_rubyfunc = query.execute

        sql_result = result_sqlfunc.to_a.collect do |hash|
          # These fields are no longer expected to be returned for groups othen than employerid.
          if test_run.group != 'employerid'
            hash.delete('lateness')
            hash.delete('payrollcontactdetail')
            hash.delete('paidto')
            hash.delete('paymenttype')
          end
        
          hash.to_a
        end

        ruby_result = result_rubyfunc.to_a.collect{ |hash| hash.to_a}

        #if ruby_result != sql_result
        #  puts query.query_string
        #end
        
        ruby_result.should eq(sql_result)
      end
    end
  end

  test_migration_for_dates(db, Time.new('1900-01-01'), Time.new('2012-09-07'), "from the beginning of data to some time in the future")

  test_migration_for_dates(db, Time.new('2012-05-01'), Time.new('2012-09-07'), "from quite some time after the beginning of data to a short time afterwards")
end
