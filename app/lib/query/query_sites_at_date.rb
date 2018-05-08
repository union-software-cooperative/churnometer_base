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

#--
# dbeswick: This class derives from QueryFilter, but QueryFilter also instantiates this class.
# This indicates that inheritance is inappropriate and the filtering functionality should be in its own
# class, with the functionality being provided through composition.
#++
# A query that returns the work sites passing the given filter that exist at the given date.
class QuerySitesAtDate < QueryFilter
  # work_site_dimension_id: The id of the dimension that holds work site date.
  #
  #--
  # dbeswick: Since this functionality is integral to Churnometer, the work site/'companyid' dimension
  # shouldn't be a user dimension. It should be an inbuilt dimension similar to 'status'.
  #++
  def initialize(app, churn_db, date, filter_terms)
    super(app, churn_db, '')
    @source = churn_db.fact_table
    @date = date
    @filter_terms = filter_terms
    @work_site_dimension = app.work_site_dimension
  end

  def query_string
    db = @churn_db.db

    sql = <<-EOS
	with last_change as
	(
		-- get the last change prior to the sample date for each member
		-- this tell us the state of each member at the sample date
		select
			max(changeid) changeid
		from
			#{db.quote_db(@source)}
		where
			changedate < #{db.sql_date(@date)}
		group by 
			memberid
	)

	, selections as
	(
		-- finds all changes matching user criteria
		select 
			* 
		from
			#{db.quote_db(@source)}
		where
			net = 1
			and changeid in (select changeid from last_change)
			#{sql_for_filter_terms(@filter_terms, true)}
 	)
	select distinct #{@work_site_dimension.column_base_name} from selections;

EOS

    sql
  end
end
