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

require './lib/settings.rb'
require './lib/churn_presenters/helpers.rb'

class ChurnPresenter
  
  attr_reader :transfers
  attr_reader :target
  attr_reader :form
  attr_reader :tables
  attr_reader :graph
  attr_reader :diags
  attr_accessor :warnings
  
  include Enumerable
  include Settings
  include ChurnPresenter_Helpers
  
  def initialize(app, request)
    @app = app
    @request = request
    
    @warnings = @request.warnings
    @transfers = ChurnPresenter_Transfers.new app, request
    @diags = ChurnPresenter_Diags.new request, @transfers.getmath_transfers?

    @form = ChurnPresenter_Form.new(
      app,
			request,
      request_group_dimensions()
    )

    @target = ChurnPresenter_Target.new(app, request) if @request.auth.role.allow_target_calculation_display? && request.type == :summary
    @graph = ChurnPresenter_Graph.new(app, request)
    @graph = nil unless (@graph.line? || @graph.waterfall?)
    @tables = ChurnPresenter_Tables.new(app, request) if has_data?
    @tables ||= {}
    
    if !has_data?
      @warnings += 'WARNING:  No data found <br/>'
    end
    
    if transfers.exists?
      @warnings += 'WARNING:  There are transfers during this period that may influence the results.  See the transfer tab below. <br />'
    end
    
    # if @request.cache_hit
    #       @warnings += "WARNING: This data has been loaded from cache <br/>"
    #     end
    #     
    #     if ChurnDBDiskCache.cache_status != ""
    #       @warnings += "WARNING: #{ChurnDBDiskCache.cache_status} <br/>"
    #     end  
  end
  
  def has_data?
    @request.has_data?
  end

  # Properties
  
  # Dimensions applicable to the request.
  def request_group_dimensions
    @request_group_dimensions ||=
      @app.groupby_display_dimensions(@request.auth.role)
  end

  # Mappings from user dimension column names to descriptions
  def request_group_names
    if @request_group_names.nil?
      @request_group_names = {}
      request_group_dimensions().each do |dimension|
        @request_group_names[dimension.id] = dimension.name
      end
    end
    
    @request_group_names
  end

  # Summary Display Methods
  def data
    @request.data
  end
  
  def tabs
    result = Hash.new
    
    if !@graph.nil? 
      result['graph'] = 'Graph'
    end
    
    if !@tables.nil?
        @tables.each do | table|
          result[table.id] = table.name
        end
    end
    
    if @transfers.exists?
        result['transfers'] = 'Transfers'
    end
    
    result['diags'] = 'Diagnostics'
    
    result
  end
 
  def to_excel
    excel(data)
  end
 
end
