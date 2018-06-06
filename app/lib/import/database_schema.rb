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

# Stubbed out David's Dimensions class in preparation for
# integrating with his code and replacing this

class Dimension2
  attr_accessor :column_base_name
end

class Dimensions2
  include Enumerable

  attr_accessor :dimension_count

  def initialize
    @dimension_count = 25
  end

  def each(&block)
    @dimension_count.times do |i|
      d = Dimension.new
      d.column_base_name = "col#{i}"
      yield d
    end
  end
end
