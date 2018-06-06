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

require './lib/services/service_autocomplete'

# Classes of autocomplete services that query the "displaytext" table
# HTTP request parameters:
# attribute: the id of a dimension.
# term: The search term. Displaytext containing the term will be returned.
class ServiceAutocompleteDisplaytext < ServiceAutocomplete
  def initialize(churn_db, churnometer_app, param_hash)
    super

    attribute = param_hash['attribute']
    search = param_hash['term']

    raise "No attribute supplied." if attribute.nil?
    raise "No search parameter supplied." if search.nil?

    dimension = churnometer_app.dimensions.dimension_for_id_mandatory(attribute)

    @query = sql_text(churn_db, dimension.column_base_name, search)
  end

  protected
  def json_to_db_column_mapping
    {
      'id' => 'id',
      'label' => 'dropdown',
      'value' => 'displaytext'
    }
  end

  def sql_text(db, attribute, search_string)
    # tokenise search string
    search_array = search_string.split(' ')

    where_clause = ""
    search_array.each do | item |
      if (!where_clause.empty?)
        where_clause += ' AND '
      end
      where_clause += "(lower(displaytext || ' (' || id || ')') like lower(#{db.db.quote('%'+item+'%')}))"
    end

    if (where_clause.empty?)
      where_clause = ' 1=1 '
    end

    "select id, displaytext, displaytext || ' (' || id || ')' as dropdown from displaytext where attribute = #{db.db.quote(attribute)} and (#{where_clause}) order by displaytext"
  end
end
