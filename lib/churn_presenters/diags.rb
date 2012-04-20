require './lib/churn_presenters/helpers.rb'

class ChurnPresenter_Diags
  
  attr_reader :sql
  attr_reader :url
  attr_reader :transfer_math
  attr_reader :cache_status
  
  include ChurnPresenter_Helpers
  
  def initialize(request, transfer_math)
    @sql = request.sql
    @url = request.url
    @transfer_math = transfer_math
    @request = request
    @cache_status = ChurnDBDiskCache.cache_status
  end
  
end