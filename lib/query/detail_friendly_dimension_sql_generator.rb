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

require './lib/dimension'
require './lib/churn_db'

class DetailFriendlyDimensionSQLGenerator
  def initialize(dimension, churn_db)
    @dimension = dimension
    @db = churn_db
  end

  def table_alias
    "dim_#{@dimension.index}"
  end

  # should be in Dimension instead?
  def old_column_name
    'old' + @dimension.column_base_name
  end

  # should be in Dimension instead?
  def new_column_name
    'new' + @dimension.column_base_name
  end

  def wherearetheynow_select_output_column
    'current' + @dimension.column_base_name
  end

  def wherearetheynow_select_clause
    "coalesce(#{@db.db.quote_db(table_alias())}.displaytext, c.#{@db.db.quote_db(new_column_name())}::varchar(50)) as #{@db.db.quote_db(wherearetheynow_select_output_column())}"
  end

  def wherearetheynow_join_displaytext_clause
    "LEFT JOIN displaytext #{@db.db.quote_db(table_alias())} ON #{@db.db.quote_db(table_alias())}.attribute::text = #{@db.db.quote(@dimension.column_base_name)}::text AND c.#{@db.db.quote_db(new_column_name())}::character varying(20)::text = #{@db.db.quote_db(table_alias())}.id::text"
  end

  def final_select_clause
    <<-EOS
	coalesce(#{@db.db.quote_db('old' + table_alias())}.displaytext, c.#{@db.db.quote_db(old_column_name())}::varchar(50)) as #{@db.db.quote_db(old_column_name())}
	, coalesce(#{@db.db.quote_db('new' + table_alias())}.displaytext, c.#{@db.db.quote_db(new_column_name())}::varchar(50)) as #{@db.db.quote_db(new_column_name())}
	, n.#{@db.db.quote_db(wherearetheynow_select_output_column())}
EOS
  end

  def final_join_displaytext_clause
    <<-EOS
		LEFT JOIN displaytext #{@db.db.quote_db('old' + table_alias())} ON #{@db.db.quote_db('old' + table_alias())}.attribute::text = #{@db.db.quote(@dimension.column_base_name)}::text AND c.#{@db.db.quote_db(old_column_name())}::character varying(20)::text = #{@db.db.quote_db('old' + table_alias())}.id::text
		LEFT JOIN displaytext #{@db.db.quote_db('new' + table_alias())} ON #{@db.db.quote_db('new' + table_alias())}.attribute::text = #{@db.db.quote(@dimension.column_base_name)}::text AND c.#{@db.db.quote_db(new_column_name())}::character varying(20)::text = #{@db.db.quote_db('new' + table_alias())}.id::text
EOS
  end

  def groupby_displaytext_clause
    <<-EOS
		#{@db.db.quote_db('old' + table_alias())}.displaytext
		, #{@db.db.quote_db('new' + table_alias())}.displaytext
EOS
  end

  def groupby_value_clause
    <<-EOS
		c.#{@db.db.quote_db(old_column_name())}
	, c.#{@db.db.quote_db(new_column_name())}
	, n.#{@db.db.quote_db(wherearetheynow_select_output_column())}
EOS
  end
end
