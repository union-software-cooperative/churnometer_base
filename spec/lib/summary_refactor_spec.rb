require './lib/churn_db'
require './lib/churn_request'
require './spec/lib/sql_ruby_refactor_testruns'

describe "'Summary' function Ruby refactor" do
  include Settings

  def self.test_migration
    # Run for all groups, with and without transactions and site constraints.
    testruns = SQLRubyRefactorTestRuns.new
    testruns.each do |test_run|
      it "should return results matching the SQL summary function with #{test_run}" do
        
        t1 = Thread.new do
          result = testruns.db(0).summary(test_run.group, 
                     test_run.date_start,
                     test_run.date_end,
                     test_run.with_trans, 
                     test_run.site_constraint, 
                     ChurnRequest.filter_xml(test_run.filter, []))

          result.to_a.collect do |hash|
            # These fields are no longer expected to be returned for groups othen than employerid.
            if test_run.group != 'employerid'
              hash.delete('lateness')
              hash.delete('payrollcontactdetail')
              hash.delete('paidto')
              hash.delete('paymenttype')
            end
        
            hash.to_a
          end
        end
        
        query_class = query_class_for_group(test_run.group)

        query = query_class.new(testruns.db(1), 
                                test_run.group, 
                                test_run.date_start,
                                test_run.date_end,
                                test_run.with_trans, 
                                test_run.site_constraint, 
                                QueryFilterTerms.from_request_params(test_run.filter))
        
        t2 = Thread.new do
          query.execute.to_a.collect{ |hash| hash.to_a }
        end

        sql_result = t1.value
        ruby_result = t2.value

        #if ruby_result != sql_result
        #  puts query.query_string
        #end
        
        ruby_result.should eq(sql_result)
      end
    end
  end

  test_migration
end
