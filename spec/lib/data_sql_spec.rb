require File.expand_path('../../spec_helper.rb', __FILE__)

describe Churnobyl::DataSql do
  let(:datasql) do
    class Dummy
      include Churnobyl::DataSql
      include Churnobyl::Helpers

      def initialize
        self.params = {}
      end
      
      def leader?
        true
      end

      attr_accessor :params
    end
    Dummy.new 
  end
  
  describe 'query' do
    it "has sensible default" do
      datasql.query.should == {
        'group_by' => 'branchid',
        'startDate' => '2011-8-14',
        'endDate' => Time.now.strftime("%Y-%m-%d"),
        'column' => '',
        'interval' => 'none',
        Filter => {
          'status' => [1, 14]      
        }
      }
    end
  end
  
  describe 'member_sql' do
    it 'real-world data' do
      datasql.params.rmerge!({
        'startDate' => '2012-02-01',
        'endDate'   => '2012-02-01'
      })
      compress(datasql.member_sql).should == "select * from churndetailfriendly20( 'memberfacthelperpaying2', 'branchid', '', '2012-02-01', '2012-02-02', true, '<search><status>1</status><status>14</status></search>' )"
    end
  end
  
  def compress(s)
    s.gsub(/\s+/, ' ').gsub(/^\s|\s$/, '')
  end
  
end