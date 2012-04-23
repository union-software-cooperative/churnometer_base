require './lib/churn_presenters/helpers.rb'

class ChurnPresenter_Diags
  
  attr_reader :sql
  attr_reader :url
  attr_reader :transfer_math
  attr_reader :cache_status
  attr_reader :role
  
  include ChurnPresenter_Helpers
  
  def initialize(request, transfer_math)
    @sql = request.sql
    @url = request.url
    @transfer_math = transfer_math
    @request = request
    @cache_status = ChurnDBDiskCache.cache_status
    @role = "staff" if request.auth.staff?
    @role = "lead" if request.auth.lead?
    @role = "leader" if request.auth.leader?
  end
  
end