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

class ChurnPresenter_Graph
  
  include Settings
  include ChurnPresenter_Helpers
  
  def initialize(app, request)
    @request = request
    @app = app
  end
    
  def series_count
    rows = @request.data.group_by{ |row| row['row_header1'] }.count
  end

  def line?
    series_count <= 30 && @request.type == :summary && @request.params['interval'] != 'none'
  end

  def waterfall?
    cnt =  @request.data.reject{ |row | row["paying_real_gain"] == '0' && row["paying_real_loss"] == '0' }.count
    cnt > 0  && cnt <= 30 && @request.type == :summary && @request.params['interval'] == 'none'
  end
  
  def waterfallItems
    a = Array.new
    @request.data.each do |row|
      i = (Struct.new(:name, :gain, :loss, :link)).new
      i[:name] = row['row_header1']
      i[:gain] = row['paying_real_gain']
      i[:loss] = row['paying_real_loss']
      i[:link] = build_url(drill_down_header(row, @app))
      a << i
    end
    a
  end
  
  def waterfallTotal
    t = 0;
    @request.data.each do |row|
      t += row['paying_real_gain'].to_i + row['paying_real_loss'].to_i
    end
    t
  end
  
  def periods
    @request.data.group_by{ |row| row['period_header'] }.sort{|a,b| a[0] <=> b[0] }
  end
  
  def pivot
    series = Hash.new
    
    rows = @request.data.group_by{ |row| row['row_header1'] }
    rows.each do | row |
      series[row[0]] = Array.new
      periods.each do | period |
        intersection = row[1].find { | r | r['period_header'] == period[0] }
        if intersection.nil? 
          series[row[0]] << "{ y: null }"
        else
          groupby_column_id = @request.groupby_column_id

          # construct the url to be used when user clicks to drill down
          url_parameters = { 
            "startDate" => intersection['period_start'], 
            "endDate" => intersection['period_end'], 
            "interval" => 'none', 
            "#{Filter}[#{groupby_column_id}]" => "#{intersection['row_header1_id']}", 
						"group_by" => @app.next_drilldown_dimension(@request.groupby_dimension).id
          }

          drilldown_url = build_url(url_parameters)

          series[row[0]] << "{ y: #{intersection['running_paying_net'] }, id: '#{drilldown_url}' }"
        end
      end
    end
  
    series
  end
  
  def lineCategories
    periods.collect { | k | "'#{k[0]}'"}.join(",") 
  end
  
  def lineSeries
    pivot.collect { | k, v | "{ name: '#{h(k)}', data: [#{v.collect{ | i | i }.join(',')}] }" }.join(",\n") 
  end
  
  def lineHeader
    col_names['row_header1']
  end
  
end
