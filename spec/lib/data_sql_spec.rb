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

require File.expand_path('../../spec_helper.rb', __FILE__)

describe ChurnDB do
  let(:datasql) do
    class ChurnDB
      def initialize
      end
      
    end
    ChurnDB.new 
  end
  
  # describe 'query' do
  #     it "has sensible default" do
  #       datasql.query.should == {
  #         'group_by' => 'branchid',
  #         'startDate' => '14 August 2011',
  #         'endDate' => Time.now.strftime(DateFormatDisplay),
  #         'column' => '',
  #         'interval' => 'none',
  #         Filter => {
  #           'status' => [1, 14, 11]      
  #         }
  #       }
  #     end
  #   end
  #   
  describe 'raw sql checks' do 
    # before :each do
    #       datasql.params.rmerge!({
    #         'startDate' => '2012-02-01',
    #         'endDate'   => '2012-02-01'
    #       })
    #     end
    #     
    describe 'summary_sql' do
      it do
        compress(datasql.summary_sql('branchid',Date.parse('2012-02-01'), Date.parse('2012-02-01'), true, '', '<search><status>1</status><status>14</status><status>11</status></search>')).should == "select * from summary( 'memberfacthelper4', 'branchid', '', '2012-02-01', '2012-02-02', true, '', '<search><status>1</status><status>14</status><status>11</status></search>' )"
      end

      it do
        # datasql.params.rmerge!({'group_by' => 'lead'})
        compress(datasql.summary_sql('lead',Date.parse('2012-02-01'),Date.parse('2012-02-01'), true, '', '<search><status>1</status><status>14</status><status>11</status></search>')).should == "select * from summary( 'memberfacthelper4', 'lead', '', '2012-02-01', '2012-02-02', true, '', '<search><status>1</status><status>14</status><status>11</status></search>' )"
      end
    end
    
    describe 'detail_sql' do
      it do
        compress(datasql.detail_sql('branchid','',Date.parse('2012-02-01'),Date.parse('2012-02-01'), true, '', '<search><status>1</status><status>14</status><status>11</status></search>')).should == "select * from detail_friendly( 'memberfacthelper4', 'branchid', '', '2012-02-01', '2012-02-02', true, '', '<search><status>1</status><status>14</status><status>11</status></search>' )"
      end

      it do
        #datasql.params.rmerge!({'group_by' => 'lead'})
        compress(datasql.detail_sql('lead','', Date.parse('2012-02-01'),Date.parse('2012-02-01'), true, '', '<search><status>1</status><status>14</status><status>11</status></search>')).should == "select * from detail_friendly( 'memberfacthelper4', 'lead', '', '2012-02-01', '2012-02-02', true, '', '<search><status>1</status><status>14</status><status>11</status></search>' )"
      end

      it do
        #datasql.params.rmerge!({'group_by' => 'areaid'})
        compress(datasql.detail_sql('areaid', '', Date.parse('2012-02-01'),Date.parse('2012-02-01'), true, '', '<search><status>1</status><status>14</status><status>11</status></search>')).should == "select * from detail_friendly( 'memberfacthelper4', 'areaid', '', '2012-02-01', '2012-02-02', true, '', '<search><status>1</status><status>14</status><status>11</status></search>' )"
      end
    end
     
    def compress(s)
      s.gsub(/\s+/, ' ').gsub(/^\s|\s$/, '')
    end
  end
  
  
end