require './lib/churn_db'
require './lib/churn_request'
require './spec/lib/sql_ruby_refactor_testruns'

db = ChurnDB.new
def db.database_config_key
  'database_regression'
end

describe "'Summary' function Ruby refactor" do
  include Settings

  def self.test_migration(db)
    # Run for all groups, with and without transactions and site constraints.
    SQLRubyRefactorTestRuns.new.each do |test_run|
      it "should return results matching the SQL summary function with #{test_run}" do
        result_sqlfunc = db.summary(test_run.group, 
                                    test_run.date_start,
                                    test_run.date_end,
                                    test_run.with_trans, 
                                    test_run.site_constraint, 
                                    ChurnRequest.filter_xml(test_run.filter, []))
        
        query_class = query_class_for_group(test_run.group)

        query = query_class.new(db, 
                                test_run.group, 
                                test_run.date_start,
                                test_run.date_end,
                                test_run.with_trans, 
                                test_run.site_constraint, 
                                QueryFilterTerms.from_request_params(test_run.filter))
        
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

  test_migration(db)
end
