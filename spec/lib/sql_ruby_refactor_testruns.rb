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

  def initialize
    # Make test runs for all combinations of the option groups given above. 
    @test_option_combinations = options_for_combination().first.product(*options_for_combination()[1..-1]).collect do |tuple|
      make_testrun(tuple)
    end
  end

  def testrun_class
    TestRun
  end

  def make_testrun(option_tuple)
    testrun_class().new(option_tuple)
  end

  def each(&block)
    @test_option_combinations.each(&block)
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
end

