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

class Query
  def initialize(churn_db)
    @churn_db = churn_db
  end

  def execute
    @churn_db.ex(query_string())
  end

  # Should be called when executing a query from a thread.
  def execute_async
    @churn_db.ex_async(query_string())
  end

protected
  # Returns the object representing the actual database (not the ChurnDB abstraction.)
  def db
    @churn_db.db
  end

  def query_string
    raise 'Provide implementation.'
  end
end
