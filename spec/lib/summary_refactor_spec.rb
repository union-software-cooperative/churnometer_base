#  Churnometer - A dashboard for exploring a membership organisations turn-over/churn
#  Copyright (C) 2012-2013 Lucas Rohde (freeChange) 
#  lukerohde@gmail.com
#
#  Churnometer is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Churnometer is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with Churnometer.  If not, see <http://www.gnu.org/licenses/>.

require './lib/churn_db'
require './lib/churn_request'
require './spec/lib/sql_ruby_refactor_testruns'

describe "'summary' function Ruby refactor" do
  include Settings

  # Run for all groups, with and without transactions and site constraints.
  testruns = SQLRubyRefactorTestRuns.new
  testruns.each do |test_run|
    it "should return results matching the SQL function with #{test_run}" do
      
      t1 = Thread.new do
        sql_text = <<-EOS
            select * 
            from summary(
              '#{testruns.db(0).fact_table()}',
              '#{test_run.group}', 
              '',
              '#{test_run.date_start.strftime(DateFormatDB)}',
              '#{(test_run.date_end+1).strftime(DateFormatDB)}',
              #{test_run.with_trans.to_s}, 
              '#{test_run.site_constraint}',
              '#{ChurnRequest.filter_xml(test_run.filter, [])}'
              )
					EOS

        result = testruns.db(0).ex_async(sql_text)

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

class SQLRubyRefactorTestRunsSummaryRunning < SQLRubyRefactorTestRuns
  class TestRunSummaryRunning < TestRun
    attr_reader :interval
    
    def initialize(option_tuple)
      super(option_tuple)
      @interval = option_tuple[5]
    end

    def to_s
      "interval '#{@interval}', #{super}"
    end
  end

  def intervals
    ['month']
  end

  def options_for_combination
    super + [ intervals() ]
  end

  def testrun_class
    TestRunSummaryRunning
  end
end

describe "'summary_running' function Ruby refactor" do
  include Settings

  # Run for all groups, with and without transactions and site constraints.
  testruns = SQLRubyRefactorTestRunsSummaryRunning.new
  testruns.each do |test_run|
    it "should return results matching the SQL function with #{test_run}" do
      
      t1 = Thread.new do
        sql_text = <<-EOS
            select * 
            from summary_running(
              '#{testruns.db(0).fact_table()}',
              '#{test_run.group}', 
              '#{test_run.interval}',
              '#{test_run.date_start.strftime(DateFormatDB)}',
              '#{(test_run.date_end+1).strftime(DateFormatDB)}',
              #{test_run.with_trans.to_s}, 
              '#{test_run.site_constraint}',
              '#{ChurnRequest.filter_xml(test_run.filter, [])}'
              )
					EOS

        result = testruns.db(0).ex_async(sql_text)

        result = result.to_a.collect{ |hash| hash.to_a }

        # result.to_a.collect do |hash|
        #   # These fields are no longer expected to be returned for groups othen than employerid.
        #   if test_run.group != 'employerid'
        #     hash.delete('lateness')
        #     hash.delete('payrollcontactdetail')
        #     hash.delete('paidto')
        #     hash.delete('paymenttype')
        #   end
          
        #   hash.to_a
        # end
      end
      
      query_class = QuerySummaryRunning

      query = query_class.new(testruns.db(1), 
                              test_run.group,
                              test_run.interval,
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
