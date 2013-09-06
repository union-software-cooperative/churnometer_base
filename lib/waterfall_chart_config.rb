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

# Used with the ChurnPresenter_Graph class to define the appearance of the waterfall graph.
class WaterfallChartConfig
  attr_accessor :title
  attr_accessor :description
  attr_accessor :gain
  attr_accessor :loss
  attr_accessor :other_gain
  attr_accessor :other_loss
  attr_accessor :combined_gain
  attr_accessor :combined_loss
  attr_accessor :running_net
  attr_accessor :net_includes_other
  attr_accessor :gain_label
  attr_accessor :loss_label
  attr_accessor :other_gain_label
  attr_accessor :other_loss_label

  def self.from_config_element(config_element)
    config_element.ensure_kindof(Hash)

    result = new()
    result.title = config_element.ensure_hashkey('title').ensure_kindof(String, NilClass)
    result.description = config_element.ensure_hashkey('description').ensure_kindof(String, NilClass)
    result.gain = config_element.ensure_hashkey('gain').ensure_kindof(String, NilClass)
    result.loss = config_element.ensure_hashkey('loss').ensure_kindof(String, NilClass)
    result.other_gain = config_element.ensure_hashkey('other_gain').ensure_kindof(String, NilClass)
    result.other_loss = config_element.ensure_hashkey('other_loss').ensure_kindof(String, NilClass)
    result.combined_gain = config_element.ensure_hashkey('combined_gain').ensure_kindof(String, NilClass)
    result.combined_loss = config_element.ensure_hashkey('combined_loss').ensure_kindof(String, NilClass)
    result.running_net = config_element.ensure_hashkey('running_net').ensure_kindof(String, NilClass)
    result.net_includes_other = config_element.ensure_hashkey('net_includes_other').ensure_kindof(TrueClass, FalseClass)
    result.gain_label = config_element.ensure_hashkey('gain_label').ensure_kindof(String, NilClass)
    result.loss_label = config_element.ensure_hashkey('loss_label').ensure_kindof(String, NilClass)
    result.other_gain_label = config_element.ensure_hashkey('other_gain_label').ensure_kindof(String, NilClass)
    result.other_loss_label = config_element.ensure_hashkey('other_loss_label').ensure_kindof(String, NilClass)
    result
  end
end
