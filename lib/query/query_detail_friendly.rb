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

require './lib/query/query_detail'
require './lib/query/detail_friendly_dimension_sql_generator'

class QueryDetailFriendly < QueryDetail
  def initialize(churn_app, churn_db, groupby_dimension, start_date, end_date, with_trans, site_constraint, filter_column, filter_param_hash)
    super

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
	#{super}
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
		memberfact c
		LEFT JOIN displaytext d2 ON d2.attribute::text = 'status'::text AND c.newstatus::character varying(20)::text = d2.id::text
		LEFT JOIN displaytext d17 ON d17.attribute::text = 'memberid'::text AND c.memberid::character varying(20)::text = d17.id::text
EOS

		sql << "\n" + friendly_generators.collect{ |g| g.wherearetheynow_join_displaytext_clause }.join("\n")

		sql << <<-EOS
	where 
		c.changeid in (select max(changeid) from memberfact m where m.memberid in (select detail.memberid from detail) group by m.memberid)
)
 SELECT
	d.memberid
	, d.row_header
	, sum(d.a1p_real_gain) a1p_real_gain
	, sum(d.a1p_newjoin) a1p_newjoin
	, sum(d.a1p_rejoin) a1p_rejoin
	, sum(d.a1p_real_loss) a1p_real_loss
	, sum(d.a1p_to_paying) a1p_to_paying
	, sum(d.a1p_to_other) a1p_to_other
	, sum(d.a1p_other_gain) a1p_other_gain
	, sum(d.a1p_other_loss) a1p_other_loss
	, sum(d.paying_real_gain) paying_real_gain
	, sum(d.paying_real_loss) paying_real_loss
	, sum(d.paying_real_net) paying_real_net
	, sum(d.paying_other_gain) paying_other_gain
	, sum(d.paying_other_loss) paying_other_loss
	, sum(d.other_gain) other_gain
	, sum(d.other_loss) other_loss
	, sum(d.posted::numeric) posted
	, sum(d.unposted::numeric) unposted
	, c.changedate::date AS changedate
	, ((coalesce(d17.displaytext,'No Name') || ' ('::text) || c.memberid::text) || ')'::text AS member
	, d1.displaytext AS oldstatus
	, d2.displaytext AS newstatus
	, n.currentstatus
EOS

		sql << "\n, " + friendly_generators.collect{ |g| g.final_select_clause }.join("\n, ")

		sql << <<-EOS
-- dbeswick: find out why these dimensions were not coalesced with new<column> as the others were in the 
-- original sql.
--	, d15.displaytext AS oldcompany
--	, d16.displaytext AS newcompany
--	, d3.displaytext AS oldbranch
--	, d4.displaytext AS newbranch
--	, d5.displaytext AS oldindustry
--	, d6.displaytext AS newindustry
	--, m.contactdetail::text
	--, m.followupnotes::text
	--, m.paymenttypeid::text
	
   FROM detail d
   JOIN memberfact c ON d.changeid = c.changeid
   LEFT JOIN wherearetheynow n on c.memberid = n.memberid
   LEFT JOIN displaytext d1 ON d1.attribute::text = 'status'::text AND c.oldstatus::character varying(20)::text = d1.id::text
   LEFT JOIN displaytext d2 ON d2.attribute::text = 'status'::text AND c.newstatus::character varying(20)::text = d2.id::text
   LEFT JOIN displaytext d17 ON d17.attribute::text = 'memberid'::text AND c.memberid::character varying(20)::text = d17.id::text
EOS

		sql << "\n" + friendly_generators.collect{ |g| g.final_join_displaytext_clause }.join("\n")

		sql << <<-EOS
   LEFT JOIN membersourceprev  m on c.memberid = m.memberid

group by 
	d.row_header
	, c.changedate::date 
	, d.memberid
	, d1.displaytext
	, d2.displaytext
	, ((d17.displaytext || ' ('::text) || c.memberid::text) || ')'::text
	, d17.displaytext
	, c.memberid
	--, m.contactdetail
	--, m.followupnotes
	--, m.paymenttypeid
	, n.currentstatus
EOS

		sql << "\n\t, " + friendly_generators.collect{ |g| g.groupby_displaytext_clause }.join("\n\t, ")
		sql << "\n\t, " + friendly_generators.collect{ |g| g.groupby_value_clause }.join("\n\t, ")

    sql
  end
end
