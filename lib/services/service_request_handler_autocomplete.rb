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

require './lib/churn_db'
require 'json'

class ServiceRequestHandlerAutocomplete
  def initialize(churnobyl_app_class)
    services = { 
      'displaytext' => ServiceAutocompleteDisplaytext,
      'nswjoins' => ServiceNSWJoins,
      'ddretention' => ServiceDDRetention,
      'ddretentionmembers' =>ServiceDDRetentionMembers
    }

    churnobyl_app_class.get "/services/autocomplete/:handler_name" do |handler_name|
      content_type :json

      service_class = services[handler_name]
      if service_class.nil?
        "No handler for '#{handler_name}'"
      else
        service = service_class.new(churn_db(), app(), params)
        service.execute
      end
    end
    
    churnobyl_app_class.after "/services/autocomplete/:handler_name" do |handler_name|
      @cr.close_db() if !@cr.nil? 
    end
  end
end

