require File.expand_path('../../spec_helper.rb', __FILE__)

describe DataSql do
  let(:datasql) do
    class DataSqlProxy
      include Helpers

      def initialize
        @params = {}
      end
      
      def leader?
        true
      end

    end
    DataSqlProxy.new 
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
  
  describe 'raw sql checks' do 
    before :each do
      datasql.params.rmerge!({
        'startDate' => '2012-02-01',
        'endDate'   => '2012-02-01'
      })
    end
    
    describe 'summary_sql' do
      it do
        compress(datasql.summary_sql).should == "select * from churnsummarydyn19( 'memberfacthelperpaying2', 'branchid', '', '2012-02-01', '2012-02-02', true, '<search><status>1</status><status>14</status></search>' )"
      end

      it do
        datasql.params.rmerge!({'group_by' => 'lead'})
        compress(datasql.summary_sql).should == "select * from churnsummarydyn19( 'memberfacthelperpaying2', 'lead', '', '2012-02-01', '2012-02-02', true, '<search><status>1</status><status>14</status></search>' )"
      end
    end
    
    describe 'member_sql' do
      it do
        compress(datasql.member_sql).should == "select * from churndetailfriendly20( 'memberfacthelperpaying2', 'branchid', '', '2012-02-01', '2012-02-02', true, '<search><status>1</status><status>14</status></search>' )"
      end

      it do
        datasql.params.rmerge!({'group_by' => 'lead'})
        compress(datasql.member_sql).should == "select * from churndetailfriendly20( 'memberfacthelperpaying2', 'lead', '', '2012-02-01', '2012-02-02', true, '<search><status>1</status><status>14</status></search>' )"
      end

      it do
        datasql.params.rmerge!({'group_by' => 'areaid'})
        compress(datasql.member_sql).should == "select * from churndetailfriendly20( 'memberfacthelperpaying2', 'areaid', '', '2012-02-01', '2012-02-02', true, '<search><status>1</status><status>14</status></search>' )"
      end
    end
    
    def compress(s)
      s.gsub(/\s+/, ' ').gsub(/^\s|\s$/, '')
    end
  end
  
  
end