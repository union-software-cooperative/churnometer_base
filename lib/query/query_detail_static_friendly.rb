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

require './lib/query/query_detail_static'
require './lib/query/detail_friendly_dimension_sql_generator'

class QueryDetailStaticFriendly < QueryDetailStatic
  def initialize(churn_app, churn_db, groupby_dimension, filter_column, member_date, site_date, filter_terms)
    super(churn_app, churn_db, groupby_dimension, filter_column, member_date, site_date, filter_terms)

    @app = churn_app
  end

  # The dimension columns that are output from the query.
  def display_dimensions
    @app.custom_dimensions
  end

  def query_string
    friendly_generators = display_dimensions.reject{ |d| d.id == 'userid' }.collect do |dimension|
      DetailFriendlyDimensionSQLGenerator.new(dimension, @churn_db)
    end

		sql = <<-EOS
with detail as
(
	#{super()}
)
, wherearetheynow as
(
	select
	c.memberid
	, d2.displaytext AS currentstatus
EOS

		sql << "\n, " + friendly_generators.collect{ |g| g.wherearetheynow_select_clause }.join("\n, ")
# dbeswick: find out why these fields were not coalesced with new<column> as the others were in the
# original sql.
#	, d16.displaytext AS currentcompany
#	, d4.displaytext AS currentbranch
#	, d6.displaytext AS currentindustry

    sql << <<-EOS
	from
		-- change query to use membersourceprev rather than most recent change in memberfact
    -- memberfact c
    -- LEFT JOIN displaytext d2 ON d2.attribute::text = 'status'::text AND c.newstatus::character varying(20)::text = d2.id::text
    membersourceprev c
    LEFT JOIN displaytext d2 ON d2.attribute::text = 'status'::text AND LOWER(c.status::character varying(20)::text) = d2.id::text
		LEFT JOIN displaytext d17 ON d17.attribute::text = 'memberid'::text AND LOWER(c.memberid::character varying(20)::text) = d17.id::text
EOS

		sql << "\n" + friendly_generators.collect{ |g| g.wherearetheynow_join_displaytext_clause }.join("\n")

    sql << <<-EOS
	where
		--c.changeid in (select max(changeid) from memberfact m where m.memberid in (select detail.memberid from detail) group by m.memberid)
    c.memberid in (select memberid from detail)
)
 SELECT
	d.memberid
	, d.row_header
	, d.paying
	, d.a1p
	, d.other
	, c.changedate::date AS changedate
	, ((coalesce(d17.displaytext,'No Name') || ' ('::text) || c.memberid::text) || ')'::text AS member
	, d1.displaytext AS oldstatus
	, d2.displaytext AS newstatus
	, n.currentstatus
EOS

		sql << "\n, " + friendly_generators.collect{ |g| g.final_select_clause }.join("\n, ")

=begin

-- dbeswick: find out why these dimensions were not coalesced with new<column> as the others were in the
-- original sql.
--	, d15.displaytext AS oldcompany
--	, d16.displaytext AS newcompany
--	, d3.displaytext AS oldbranch
--	, d4.displaytext AS newbranch
--	, d5.displaytext AS oldindustry
--	, d6.displaytext AS newindustry

=end

    sql << <<-EOS
   FROM detail d
   JOIN memberfact c ON d.changeid = c.changeid
   LEFT JOIN wherearetheynow n on c.memberid = n.memberid
   LEFT JOIN displaytext d1 ON d1.attribute::text = 'status'::text AND c.oldstatus::character varying(20)::text = d1.id::text
   LEFT JOIN displaytext d2 ON d2.attribute::text = 'status'::text AND c.newstatus::character varying(20)::text = d2.id::text
   LEFT JOIN displaytext d17 ON d17.attribute::text = 'memberid'::text AND c.memberid::character varying(20)::text = d17.id::text
EOS

		sql << "\n" + friendly_generators.collect{ |g| g.final_join_displaytext_clause }.join("\n")

    # order by the detail query's groupby dimension column (row header), then the member name and id.
    sql << <<-EOS
	 order by
 		row_header
 		, ((d17.displaytext || ' ('::text) || c.memberid::text) || ')'::text
		EOS

    sql
  end
end
