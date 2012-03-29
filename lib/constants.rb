# Short names to help shorten URL
Filter = "f"
FilterNames = "fn"
MonthlyTransferWarningThreshold = Float(1.0 * 2.0 / 36.0); # 100% of the membership churns from development to growth and back every 3 years 
DateFormatDisplay = "%e %B %Y"
DateFormatPicker = "'d MM yy'"
DateFormatDB = "%Y-%m-%d"

EarliestStartDate = Date.new(2011,8,14)

def col_names 
  hash = {
    'row_header1'     => Mappings.groups_by_collection[(params['group_by'] || 'branchid')].downcase,
    'row_header'     => Mappings.groups_by_collection[(params['group_by'] || 'branchid')].downcase,
    'a1p_real_gain'   => 'total cards in',
    'a1p_to_other'    => 'cards failed',
    'paying_start_count' => 'paying at start date',
    'paying_real_gain'  => 'started paying',
    'paying_real_loss'  => 'ceased paying',
    'a1p_start_count' => 'a1p at start',
    'a1p_end_count' => 'a1p at end',
    'paying_real_net'   => 'paying net',
    'paying_end_count'  => 'paying at end date',
    'posted'            => 'income posted',
    'unposted'            => 'income corrections',
    'income_net'            => 'income net',
    'running_paying_net'  => 'paying net (running total)',
    'paying_other_loss'   => 'paying transfers out',
    'paying_other_gain'   => 'paying transfers in',
    'a1p_other_gain'     => 'a1p transfers in',
    'a1p_other_loss'     => 'a1p transfers out',
    'a1p_newjoin'        => 'cards in (new)',
    'a1p_rejoin'         => 'cards in (rejoin)',
    'a1p_to_paying'     => 'a1p started paying',
    #'a1p_real_loss'     => 'a1p never paid',
    'period_header'       => 'interval',
    'start_date'          => 'start date',
    'end_date'          => 'end date',
    'annualisedavgcontribution' => 'estimated annual contribution',
    'contributors'  => 'unique contributors',
    'stopped_start_count' => 'stopped paying at start date', 
    'stopped_end_count' => 'stopped paying at end date',
    'stopped_real_gain' => 'became stopped paying',
    'stopped_real_loss' => 'ceased stopped paying',
    'stopped_other_gain' => 'stopped transfers in',
    'stopped_other_loss' => 'stopped transfers out'
    }
end


module Mappings
  class << self
    def groups_by_collection
      {
        "branchid"      => "Branch",
        "lead"          => "Lead Organiser",
        "org"           => "Organiser",
        "areaid"        => "Area",
        "companyid"     => "Work Site",
        "industryid"    => "Industry",
        #"del"           => "Delegate Training",
        #"hsr"           => "HSR Training",
        "nuwelectorate" => "Electorate",
        "state"         => "State",
        "feegroupid"    => "Fee Group",
        "staffid"       => "Staff"
      }
    end
    
    
  end
end