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

class ChurnPresenter_Form
  
  include ChurnPresenter_Helpers
  include Settings

  def initialize(app, request, group_dimensions)
    @app = app
    @request = request
    @group_dimensions = group_dimensions
  end
  
  def [](index)
    @request.params[index]
  end
  
  def filters
    if @filters.nil?
      @filters = Array.new
      
      f1 = @request.parsed_params[Filter].reject{ |column_name, id | id.empty? }
      f1 = f1.reject{ |column_name, id | column_name == 'status' }

      if !f1.nil?
        f1.each do |column_name, ids|
          Array(ids).each do |id|
            if (filter_value(id) != '')
              dimension = @group_dimensions.dimension_for_id(column_name)

              i = (Struct.new(:name, :group, :id, :display, :type)).new
              i[:name] = column_name
              i[:group] = dimension.name
              i[:id] = filter_value(id)
              i[:display] = @request.db.get_display_text(dimension, filter_value(id))
              i[:type] = (id[0] == '-' ? "disable" : ( id[0] == '!' ? "invert" : "apply" ))
              @filters << i
            end
          end
        end
      end 
    end
    
    @filters
  end
  
  def row_header_id_list
    @request.data.group_by{ |row| row['row_header1_id'] }.collect{ | rh | rh[0] }.join(",")
  end

  def output_group_selector(selected_group_id, control_name, control_id='')
    output = "<select name='#{control_name}' id='#{control_id}'>"

    @group_dimensions.sort_by { | d | d.name }.each do |dimension|
      attributes = 
        if dimension.id == selected_group_id
          "selected='selected'"
        else
          ""
        end
      
      output << "<option value='#{h dimension.id}' #{attributes}>#{h dimension.name}</option>"
    end

    output << "</select>"
    output
  end
  
  def output_period_selector(selected_period_id)
    selected = {}
    selected[selected_period_id] = "selected='selected'"
    
    output = "<select id='period' name='period' onchange='period_changed()'>"
    output << <<-HTML
      <option value='today' #{selected['today']}>Today</option>
      <option value='yesterday' #{selected['yesterday']}>Yesterday</option>
      <option value='this_week' #{selected['this_week']}>This Week</option>
      <option value='last_week' #{selected['last_week']}>Last Week</option>
      <option value='this_month' #{selected['this_month']}>This Month</option>
      <option value='last_month' #{selected['last_month']}>Last Month</option>
      <option value='this_year' #{selected['this_year']}>This Year</option>
      <option value='last_year' #{selected['last_year']}>Last Year</option>
      <option value='custom' #{selected['custom']}>Custom...</option>
    HTML
    
    output << "</select>"
    output
  end

  def output_filter_group_search_term_editor
    <<-EOS
			<input type=text id=search_term_add_text onfocus='$("#search_term_add_text").autocomplete("search");'/>
			<input type=hidden id=search_term_add_id_hidden />
		  <input type=hidden id=search_term_filter_count_hidden value=#{filters.count} />
    EOS
  end

  private

  def filter_value(value)
    value.sub('!','').sub('-','')
  end
  
end
