require './lib/churn_presenters/helpers.rb'
require './lib/settings.rb'

class ChurnPresenter_Transfers
  
  include Settings
  include ChurnPresenter_Helpers
  
  def initialize(request)
    @request = request
  end
  
  def exists?
    # count the transfers, including both in and out
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate'])
    months = Float(end_date - start_date) / 30.34
    
    t=0
    @request.data.each do |row|
      t += row['external_gain'].to_i - row['external_loss'].to_i
    end

    startcnt =  paying_start_total
    endcnt = paying_end_total
    
    threshold = ((startcnt + endcnt)/2 * (MonthlyTransferWarningThreshold * months))
    t > threshold ? true : false
  end
  
  def transfers
    @request.get_transfers
  end
  
  def getmath_transfers?
    # count the transfers, including both in and out
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate'])
    months = Float(end_date - start_date) / 30.34
    
    t=0
    @request.data.each do |row|
      t += row['external_gain'].to_i - row['external_loss'].to_i
    end

    startcnt =  paying_start_total
    endcnt = paying_end_total

    threshold = ((startcnt + endcnt)/2 * (MonthlyTransferWarningThreshold * months))
    t > threshold ? true : false
  
    "The system will warn the user and display this tab, when the external transfer total (#{t}) is greater than the external transfer threshold (#{threshold.round(0)} = (average size (#{(startcnt+endcnt)/2} = (#{col_names['paying_start_count']} (#{startcnt}) + #{col_names['paying_end_count']} (#{endcnt}))/2) * MonthlyThreshold (#{(MonthlyTransferWarningThreshold*100).round(1)}%) x months (#{months.round(1)}))).  The rational behind this formula is that 100% of the membership will transfer to growth from development and back every three years (2.8% in and 2.8% out each month). So transfers below this threshold are typical and can be ignored, as opposed to atypical area restructuring of which the user needs warning."
  end
  
  def start_date
    @request.params['startDate']
  end
  
  def end_date
    @request.params['endDate']
  end
  
end

