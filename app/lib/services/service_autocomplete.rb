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

require './lib/churnometer_app'

# Base class for services that provide autocomplete data to clients.
# churn_db: ChurnDB instance.
# churnometer_app: The ChurnometerApp instance.
class ServiceAutocomplete
  def initialize(churn_db, churnometer_app, param_hash)
    @app = churnometer_app
    @db = churn_db
  end

  def present_db_result(db_result)
    db_result_to_json(db_result)
  end

  def max_results
    50
  end

  def execute
    db_result = @db.ex(@query)

    result = []

    db_result.each do |row_hash|
      result << db_hash_to_json_hash(row_hash)

      break if result.length == max_results()
    end

    JSON[result]
  end

  def close_db
    @db.close_db()
  end

  protected
  def db_hash_to_json_hash(db_row_hash)
    result = {}

    json_to_db_column_mapping().each do |json_column, db_column|
      db_value = db_row_hash[db_column]

      if db_value.nil?
        raise "Database column '#{db_column}' for json result column '#{json_column}' wasn't returned in the query result."
      end

      result[json_column] = db_value
    end

    result
  end

  def json_to_db_column_mapping
  end
end
