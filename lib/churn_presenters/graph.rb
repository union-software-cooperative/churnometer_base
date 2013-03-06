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
  
  def initialize(app, request, chart_config = nil)
    @request = request
    @app = app
  
    @chart_config = chart_config
    @chart_config ||= {
      :title => 'new members vs new problems vs exited members',
      :gain => 'member_real_gain_fee',
      :loss => 'member_real_loss_fee',
      :other_gain => nil,
      :other_loss => 'member_real_loss_orange',
      :running_net => 'running_member_net'
    }
  end
    
  def title
    @chart_config[:title]
  end
  
  def series_count
    rows = @request.data.group_by{ |row| row['row_header1'] }.count
  end

  def line?
    @request.params['interval'] != 'none' && series_count <= 30 && @request.type == :summary && @request.groupby_column_id != 'userid'
  end

  def waterfall?
    cnt =  @request.data.reject{ |row | row[@chart_config[:gain]] == '0' && row[@chart_config[:loss]] == '0' }.count
    
    @request.params['interval'] == 'none' && cnt > 0  && cnt <= 30 && @request.type == :summary &&  @request.groupby_column_id != 'userid'
  end
  
  def waterfallItems
    a = Array.new
    @request.data.each do |row|
      i = (Struct.new(:name, :gain, :loss, :other_gain, :other_loss, :name_link, :gain_link, :loss_link, :other_gain_link, :other_loss_link)).new
      i[:name] = row['row_header1']
      i[:gain] = 0
      i[:loss] = 0
      i[:other_gain] = 0
      i[:other_loss] = 0
      
      i[:gain] = row[@chart_config[:gain]] unless @chart_config[:gain].nil?
      i[:loss] = row[@chart_config[:loss]] unless @chart_config[:loss].nil?
      i[:other_gain] = row[@chart_config[:other_gain]] unless @chart_config[:other_gain].nil?
      i[:other_loss] = row[@chart_config[:other_loss]] unless @chart_config[:other_loss].nil?
      
      i[:name_link] = build_url(drill_down_header(row, @app))
      i[:gain_link] = build_url(drill_down_cell(row, @chart_config[:gain])) unless @chart_config[:gain].nil?
      i[:loss_link] = build_url(drill_down_cell(row, @chart_config[:loss])) unless @chart_config[:loss].nil?
      i[:other_gain_link] = build_url(drill_down_cell(row, @chart_config[:other_gain])) unless @chart_config[:other_gain].nil?
      i[:other_loss_link] = build_url(drill_down_cell(row, @chart_config[:other_loss])) unless @chart_config[:other_loss].nil?
      a << i
    end
    a
  end
  
  def waterfallTotal
    t = 0;
    @request.data.each do |row|
      t += row[@chart_config[:gain]].to_i + row[@chart_config[:loss]].to_i
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

          series[row[0]] << "{ y: #{intersection[@chart_config[:running_net]] }, id: '#{drilldown_url}' }"
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
