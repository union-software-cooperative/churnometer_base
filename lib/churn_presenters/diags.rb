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
