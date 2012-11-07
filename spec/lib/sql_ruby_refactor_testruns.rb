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

require './lib/settings'

Dir["./lib/query/*.rb"].each { |f| require f }

# A class to clearly define and express the data being tested in each run in all combinations.
class SQLRubyRefactorTestRuns
  include Settings

  class TestRun
    attr_reader :group
    attr_reader :with_trans
    attr_reader :site_constraint
    attr_reader :filter
    attr_reader :filter_description
    attr_reader :date_start
    attr_reader :date_end
    attr_reader :date_description
    attr_accessor :message

    def initialize(option_tuple)
      @group = option_tuple[0]
      @with_trans = option_tuple[1]
      @site_constraint = option_tuple[2]
      
      @filter = option_tuple[3].first
      @filter_description = option_tuple[3].last

      @date_start = option_tuple[4][0]
      @date_end = option_tuple[4][1]
      @date_description = option_tuple[4][2]
    end

    def start
      $stdout.puts @message if @message
    end

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
      
      "group '#{group}', #{transactions_descriptor}, #{site_constraint_descriptor}, #{filter_description}, with dates #{date_description}"
    end
  end

  # If limit is non-nil, the number of combinations is limited to a randomly-chosen set of 'limit'
  # combinations. Specifying the random_seed allows repeatable testing.
  def initialize(limit = nil, random_seed = nil)
    @limit = limit
    @random_seed = random_seed
  end

  def test_option_combinations
    @test_options_combinations ||= 
      begin
        combinations = options_for_combination()
        combinations = combinations.first.product(*combinations[1..-1])

        testrun_initiation_message = nil
        if @limit
          @rnd = Random.new
          @rnd.srand(@random_seed) if @random_seed
          testrun_initiation_message = "NOTE: TESTING RANDOM SET OF #{@limit} COMBINATIONS, SEED #{@rnd.seed}."
          combinations = combinations.sort_by{ @rnd.rand }[0...@limit]
        end

        # Make test runs for all combinations of the option groups given above.
        combinations.collect! do |tuple|
        	make_testrun(tuple)
      	end
        
        combinations.first.message = testrun_initiation_message

        combinations
      end
  end

  def testrun_class
    TestRun
  end

  def make_testrun(option_tuple)
    testrun_class().new(option_tuple)
  end

  def each(&block)
    test_option_combinations().each(&block)
  end

  def groups
    # Pass 'is_leader' and 'is_admin' true to get the full set of groups
    group_names(true, true).keys
  end

  def transaction_options
    [true, false]
  end

  def site_constraint_options
    ['', 'start', 'end']
  end

  # the tuples here are [date start, date end, date description]
  def date_options
    [[Time.new('1900-01-01'), Time.new('2012-09-07'), "from the beginning of data to some time in the future"],
     [Time.new('2012-05-01'), Time.new('2012-09-07'), "from quite some time after the beginning of data to a short time afterwards"]]
  end
  
  # the tuples here are [filter xml, filter description]
  def filter_options
    [[{"status"=>[1,14,11]}, 'no filter'],
     [{"status"=>[1,14,11],"branchid"=>'b1'}, 'simple filter'],
     [{"status"=>[1,14,11],"branchid"=>['-b1','b2'],"lead"=>'l2',"org"=>'!o7'}, 'complex filter'],
     [{"status"=>[1,14,11],'branchid'=>'b2','lead'=>'!l2','statusstaffid'=>'d2'}, 'complex filter with statusstaffid term']
    ]
  end

  def options_for_combination
    [
     groups(),
     transaction_options(),
     site_constraint_options(),
     filter_options(),
     date_options()
    ]
  end

  def db(index)
    @dbs ||= {}
    
    @dbs[index] ||= 
      begin
        db = ChurnDB.new
        
        def db.database_config_key
          'database_regression'
        end
        
        db
      end
  end
end

