require './lib/churn_presenters/helpers.rb'

class ChurnPresenter_Diags
  
  attr_reader :sql
  attr_reader :url
  attr_reader :transfer_math
  attr_reader :cache_status
  attr_reader :role
  attr_reader :rows
  attr_reader :filter
  attr_reader :filter_xml
  
  include ChurnPresenter_Helpers
  
  def initialize(request, transfer_math)
    @sql = request.sql
    @url = request.url
    @transfer_math = transfer_math
    @request = request
    @cache_status = ChurnDBDiskCache.cache_status
    @role = request.auth.role
    @rows = request.data.length if !request.data.nil?
    @rows ||= 0
    @filter = request.parsed_params()[Filter]
    @filter_xml = request.xml
  end
  
end
