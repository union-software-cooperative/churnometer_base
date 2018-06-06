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

require './lib/query/query_filter'

# Abstract base class containing common functionality for the family of Detail queries.
class QueryDetailBase < QueryFilter
  def initialize(app, churn_db, groupby_dimension, filter_column, filter_terms)
    super(app, churn_db, filter_terms)
    @groupby_dimension = groupby_dimension
    @filter_column = filter_column
  end

  # Returns a map of filter column names to sql 'where' clause text, defining the clause to be used
  # when the filter column is supplied to the object.
  def self.filter_column_to_where_clause
    {}
  end

  def where_clause_for_filter_column(filter_column)
    clause = self.class.filter_column_to_where_clause[filter_column]

    if clause.nil?
      raise "Invalid filter column '#{filter_column}'"
    end

    clause
  end
end
