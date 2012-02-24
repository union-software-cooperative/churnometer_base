require File.expand_path('../../spec_helper.rb', __FILE__)

describe Churnobyl::DataSql do
  let(:datasql) do
    class Dummy
      include Churnobyl::DataSql
      
      def params
        {}
      end
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
end