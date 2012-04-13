require File.expand_path('../../spec_helper.rb', __FILE__)

describe ChurnData do
  let(:datasql) do
    class ChurnData
      def initialize
        @params = {}
      end
      
    end
    ChurnData.new 
  end
  
  describe 'query' do
    it "has sensible default" do
      datasql.query.should == {
        'group_by' => 'branchid',
        'startDate' => '14 August 2011',
        'endDate' => Time.now.strftime(DateFormatDisplay),
        'column' => '',
        'interval' => 'none',
        Filter => {
          'status' => [1, 14, 11]      
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
        compress(datasql.summary_sql(true)).should == "select * from summary( 'memberfacthelper4', 'branchid', '', '2012-02-01', '2012-02-02', true, '', '<search><status>1</status><status>14</status><status>11</status></search>' )"
      end

      it do
        datasql.params.rmerge!({'group_by' => 'lead'})
        compress(datasql.summary_sql(true)).should == "select * from summary( 'memberfacthelper4', 'lead', '', '2012-02-01', '2012-02-02', true, '', '<search><status>1</status><status>14</status><status>11</status></search>' )"
      end
    end
    
    describe 'member_sql' do
      it do
        compress(datasql.member_sql(true)).should == "select * from detail_friendly( 'memberfacthelper4', 'branchid', '', '2012-02-01', '2012-02-02', true, '', '<search><status>1</status><status>14</status><status>11</status></search>' )"
      end

      it do
        datasql.params.rmerge!({'group_by' => 'lead'})
        compress(datasql.member_sql(true)).should == "select * from detail_friendly( 'memberfacthelper4', 'lead', '', '2012-02-01', '2012-02-02', true, '', '<search><status>1</status><status>14</status><status>11</status></search>' )"
      end

      it do
        datasql.params.rmerge!({'group_by' => 'areaid'})
        compress(datasql.member_sql(true)).should == "select * from detail_friendly( 'memberfacthelper4', 'areaid', '', '2012-02-01', '2012-02-02', true, '', '<search><status>1</status><status>14</status><status>11</status></search>' )"
      end
    end
     
    def compress(s)
      s.gsub(/\s+/, ' ').gsub(/^\s|\s$/, '')
    end
  end
  
  
end