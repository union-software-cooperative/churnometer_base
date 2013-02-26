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

require 'date'
require 'yaml'

# Short names to help shorten URL
Filter = "f"
FilterNames = "fn"
MonthlyTransferWarningThreshold = Float(1.0 * 2.0 / 36.0); # 100% of the membership churns from development to growth and back every 3 years 
DateFormatDisplay = "%e %B %Y"
DateFormatPicker = "'d MM yy'"
DateFormatDB = "%Y-%m-%d"
MaxMemberList = 500

module Settings
  # Return the ChurnometerApp instance
  def app
    @app
  end

  def query_defaults
    start_date = app.application_start_date.strftime(DateFormatDisplay)
    end_date = Time.now.strftime(DateFormatDisplay)
    
    defaults = {
      'group_by' => app().groupby_default_dimension.id,
      'startDate' => start_date,
      'endDate' => end_date,
      'column' => '',
      'interval' => 'none',
      Filter => {
        'status' => [
           app().member_paying_status_code,
           app().member_awaiting_first_payment_status_code,
           app().member_stopped_paying_status_code
        ] + app().waiver_statuses # todo - get rid of this because exceptions are required for it when displaying filters
      }
    }
  end

  # Classes that should be used to handle summary queries for specific groups.
  def summary_query_class_groupby_overrides
    {
    }    
  end

  def query_class_for_group(group_column_name)
    query_class_symbol = 
      if summary_query_class_groupby_overrides().has_key?(group_column_name)
        summary_query_class_groupby_overrides()[group_column_name]
      else
        app().summary_query_class
      end
        
    query_class = eval(query_class_symbol.to_s)
  end

  def interval_names
    [
      ["none", "Off"],
      ["week", "Weekly"],
      ["month", "Monthly"],
    ]
  end
  
     def col_names 
       # dbeswick: temporary until Settings is refactored away.
       raise "Class '#{self.class}' must provide the churnometer app instance in @app because it mixes in the Settings module." if @app.nil?

       row_header_col_name = @request.groupby_column_name.downcase
         
       hash = {
         'row_header1'     => row_header_col_name,
         'row_header'     => row_header_col_name,
         'period_header'       => "#{@request.params['interval']} beginning"
        }
        hash.merge @app.col_names
     end
     
     def filter_columns 
       %w{
         a1p_real_gain 
         a1p_unchanged_gain
         a1p_real_loss 
         a1p_real_net
         a1p_other_gain 
         a1p_other_loss 
         paying_real_gain 
         paying_real_loss 
         paying_other_gain 
         paying_other_loss 
         other_other_gain 
         other_other_loss
         a1p_newjoin
         a1p_rejoin
         a1p_to_other
         a1p_to_paying
         paying_real_net
         other_gain
         other_loss
         stopped_real_gain
         stopped_unchanged_gain
         stopped_real_loss
         stopped_real_net
         stopped_to_paying
         stopped_to_other
         stopped_other_gain
         stopped_other_loss
         contributors
         income_net
         posted
         unposted
         transactions
         waiver_real_gain
     		 waiver_real_loss
     		 waiver_real_gain_good
      	 waiver_real_gain_bad
         waiver_real_loss_good
         waiver_real_loss_bad
         waiver_real_net
     		 waiver_other_gain
     		 waiver_other_loss
         member_real_gain
     		 member_real_gain_nofee
         member_real_gain_fee
         member_real_loss
     		 member_real_loss_nofee
         member_real_loss_fee
         member_real_net
     		 member_other_gain
     		 member_other_loss
     		 member_real_loss_orange
         member_real_gain_orange
     		 nonpaying_real_gain_good
     		 nonpaying_real_loss_good
     		 nonpaying_real_gain_bad
     		 nonpaying_real_loss_bad
         nonpaying_real_net
     		 nonpaying_other_gain
     		 nonpaying_other_loss
         }
     end
     
     def bold_col?(column_name)
       [
         'paying_real_net',
         'running_paying_net',
         'a1p_real_gain',
         'transactions',
       ].include?(column_name)
     end
     
     def no_total

       nt = [
         'row_header',
         'row_header_id',
         'row_header1',
         'row_header1_id',
         'row_header2',
         'row_header2_id',
         'contributors', 
         'annualisedavgcontribution',
         'running_paying_net', 
         'lateness',
         'paymenttype',
         'paymenttypeid',
         'paidto',
         'followupnotes',
         'contactdetail',
         'newemployer',
         'payrollcontactdetail'
       ]

       if @request.params['interval'] != 'none'
         nt += [
           'paying_start_count',
           'paying_end_count',
           'period_header',
           'a1p_start_count',
           'a1p_end_count',
           'stopped_start_count',
           'stopped_end_count',
           'member_start_count',
           'member_end_count',
           'waiver_start_count',
           'waiver_end_count',
           'nonpaying_start_count',
           'nonpaying_end_count'
         ]
       end

       nt
     end

     def date_cols
       [
         'period_header', 
         'paidto', 
         'changedate'
       ]
     end

     def tips
      result = {}
      
      # substitute any reference in the tooltip to {group_by} 
      # with the currently grouped dimension
      row_header_col_name = @request.groupby_column_name.downcase
      app().col_descriptions.each do | k, v |
        v.gsub! '{group_by}', row_header_col_name
        result[k] = v
      end  
      result
     end

end
