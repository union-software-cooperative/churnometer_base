require './lib/query/query_filter'
require './lib/query/query_sites_at_date'

class QuerySummary < QueryFilter
  # groupby_dimension: A Dimension instance by which results will be grouped.
  # filter_terms: A FilterTerms instance.
  # groupby_dimension: A Dimension instance.
  def initialize(app, churn_db, groupby_dimension, start_date, end_date, with_trans, site_constraint, filter_terms)
    super(app, churn_db, filter_terms)
    @groupby_dimension = groupby_dimension
    @start_date = start_date
    @end_date = end_date
    @with_trans = with_trans
    @site_constraint = site_constraint
  end

  def query_string
    db = @churn_db.db

    header1 = @groupby_dimension.column_base_name

    filter = modified_filter_for_site_constraint(filter_terms(), @site_constraint, @start_date, @end_date)

    non_status_filter = filter.exclude('status')
    user_selections_filter = filter.include('status')

    end_date = @end_date + 1

    paying_db = db.quote(@app.member_paying_status_code)
    a1p_db = db.quote(@app.member_awaiting_first_payment_status_code)
    stoppedpay_db = db.quote(@app.member_stopped_paying_status_code)

sql = <<-EOS
	-- summary query
	with nonstatusselections as
	(
		-- finds all changes matching user criteria
		select 
			* 
		from
			#{@source} 
		where
			changedate <= #{db.sql_date(end_date)} -- we need to count every value since Churnobyls start to determine start_count.  But everything after enddate can be ignored.
			#{sql_for_filter_terms(non_status_filter, true)}
	)
	, userselections as 
	(
		select
			*
		from
			nonstatusselections
		where
			#{sql_for_filter_terms(user_selections_filter, false)}
	)
	, nonegations as
	(
		-- removes changes that make no difference to the results or represent gains and losses that cancel out
		select
			*, case when u1.changeid in (select changeid from userselections u group by changeid having sum(u.net) <> 0) then false else true end internalTransfer
		from 
			userselections u1
		where
			u1.changeid in (select changeid from userselections u group by changeid having sum(u.net) <> 0) -- any change who has only side in the user selection 
			or u1.changeid in (select changeid from userselections u where payinggain <> 0 or payingloss <> 0 ) -- both sides (if in user selection) if one side is paying and there was a paying change 
 			or u1.changeid in (select changeid from userselections u where a1pgain <> 0 or a1ploss <> 0) -- both sides (if in user selection) if one side is paying and there was a paying change 
 			or u1.#{header1}delta <> 0 -- unless the changes that cancel out but are transfers between grouped items
 	)
	, trans as
	(
		select 
			case when coalesce(u1.#{header1}::varchar(200),'') = '' then 'unassigned' else u1.#{header1}::varchar(200) end row_header1
		, sum(case when amount::numeric > 0.0 then amount::numeric else 0.0 end) posted
		, sum(case when amount::numeric < 0.0 then amount::numeric else 0.0 end) undone
		, sum(amount::numeric) income_net
		, count(distinct t.memberid) contributors
		, sum(amount::numeric) / count(distinct t.memberid) avgContribution
		, ( sum(amount::numeric) / count(distinct t.memberid)::numeric ) / (#{db.sql_date(end_date)}::date - #{db.sql_date(@start_date)}::date) * 365::numeric annualizedAvgContribution
		, count(*) transactions
	from
		transactionfact t
		inner join nonstatusselections u1 on
			u1.net = 1
			and u1.changeid = t.changeid
	where
		t.creationdate > #{db.sql_date(@start_date)}
		and t.creationdate <= #{db.sql_date(end_date)}
	group by
		case when coalesce(u1.#{header1}::varchar(200),'') = '' then 'unassigned' else u1.#{header1}::varchar(200) end
	)
	, counts as
	(
		-- sum changes, if status doesnt change, then the change is a transfer
		select 
			case when coalesce(#{header1}::varchar(200),'') = '' then 'unassigned' else #{header1}::varchar(200) end row_header1
			--, date_trunc('week', changedate)::date row_header2
			, sum(case when changedate <= #{db.sql_date(@start_date)} then net else 0 end) as start_count
			, sum(case when changedate <= #{db.sql_date(@start_date)} and status = #{a1p_db} then net else 0 end) as a1p_start_count -- cant use a1pgain + a1ploss because they only count when a status changes, where as we want every a1p value in the selection, even if it is a transfer
			, sum(case when changedate <= #{db.sql_date(@start_date)} and status = #{paying_db} then net else 0 end) as paying_start_count
			, sum(case when changedate <= #{db.sql_date(@start_date)} and status = #{stoppedpay_db} then net else 0 end) as stopped_start_count
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and _changeid is null then a1pgain else 0 end) a1p_unchanged_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status, '') = '' then a1pgain else 0 end) a1p_newjoin
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status, '') <>'' then a1pgain else 0 end) a1p_rejoin			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status,'') = #{paying_db} then a1ploss else 0 end) a1p_to_paying
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status,'') <> #{paying_db} then a1ploss else 0 end) a1p_to_other			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status,'') = #{paying_db} then stoppedloss else 0 end) stopped_to_paying
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status,'') <> #{paying_db} then stoppedloss else 0 end) stopped_to_other			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{a1p_db} then othergain else 0 end) a1p_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{a1p_db} then otherloss else 0 end) a1p_other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{paying_db} then othergain else 0 end) paying_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{paying_db} then otherloss else 0 end) paying_other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{stoppedpay_db} then othergain else 0 end) stopped_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{stoppedpay_db} then otherloss else 0 end) stopped_other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and not (status = #{paying_db} or status = #{a1p_db} or status = #{stoppedpay_db}) then othergain else 0 end) other_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and not (status = #{paying_db} or status = #{a1p_db} or status = #{stoppedpay_db}) then otherloss else 0 end) other_other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and _changeid is null and coalesce(_status,'') = '3' then loss else 0 end) rule59_unchanged_gain
			, sum(case when status = #{a1p_db} then net else 0 end) as a1p_end_count -- cant use a1pgain + a1ploss because they only count when a status changes, where as we want every a1p value in the selection, even if it is a transfer
			, sum(case when status = #{paying_db} then net else 0 end) as paying_end_count
			, sum(case when status = #{stoppedpay_db} then net else 0 end) as stopped_end_count
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and _changeid is null then stoppedgain else 0 end) stopped_unchanged_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and not internalTransfer then othergain else 0 end) external_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and not internalTransfer then otherloss else 0 end) external_loss
			, sum(net) as end_count
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then a1pgain else 0 end) a1p_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then a1ploss else 0 end) a1p_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then payinggain else 0 end) paying_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then payingloss else 0 end) paying_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then stoppedgain else 0 end) stopped_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then stoppedloss else 0 end) stopped_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then othergain else 0 end) other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then otherloss else 0 end) other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then a1pgain+a1ploss else 0 end) a1p_net
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then payinggain+payingloss else 0 end) paying_net
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then stoppedgain+stoppedloss else 0 end) stopped_net
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then othergain+otherloss else 0 end) other_net
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then coalesce(c.net,0) else 0 end) net
			
		from 
			nonegations c
		group by 
			case when coalesce(#{header1}::varchar(200),'') = '' then 'unassigned' else #{header1}::varchar(200) end 
	)
	, withtrans as
	(
		select
			c.*
EOS

sql << 
  if @with_trans 
<<-EOS
			, coalesce(t.posted,0)::numeric(12,2) posted
			, coalesce(t.undone,0)::numeric(12,2) unposted
			, coalesce(t.income_net,0)::numeric(12,2) income_net
			, contributors
			, transactions
			, annualizedAvgContribution::numeric(12,2) annualizedAvgContribution
EOS
  else
<<-EOS
		, 0::numeric posted
			, 0::numeric unposted
			, 0::numeric income_net 
			, 0::int contributors
			, 0::int transactions
			, 0::numeric annualizedAvgContribution
EOS
  end

sql <<
<<-EOS
		from
			counts c
EOS

if @with_trans
sql << <<-EOS
			left join trans t on t.row_header1 = c.row_header1

		union all

		select
			t.row_header1
			, 0::int start_count
			, 0::int a1p_start_count
			, 0::int paying_start_count
			, 0::int stopped_start_count
			, 0 a1p_gain
			, 0 a1p_unchanged_gain
			, 0 a1p_newjoin
			, 0 a1p_rejoin
			, 0 a1p_loss
			, 0 a1p_to_paying
			, 0 a1p_to_other
			, 0 paying_gain
			, 0 paying_loss
			, 0 stopped_gain
			, 0 stopped_unchanged_gain
			, 0 rule59_unchanged_gain
			, 0 stopped_loss
			, 0 stopped_to_paying
			, 0 stopped_to_other
			, 0 a1p_other_gain
			, 0 a1p_other_loss
			, 0 paying_other_gain
			, 0 paying_other_loss
			, 0 stopped_other_gain
			, 0 stopped_other_loss
			, 0 other_other_gain
			, 0 other_other_loss
			, 0 other_gain
			, 0 other_loss
			, 0 external_gain
			, 0 external_loss
			, 0 a1p_net
			, 0 paying_net
			, 0 stopped_net
			, 0 other_net
			, 0 net
			, 0 end_count
			, 0 a1p_end_count
			, 0 paying_end_count
			, 0 stopped_end_count
			, coalesce(t.posted,0)::numeric(12,2) posted
			, coalesce(t.undone,0)::numeric(12,2) unposted
			, income_net
			, contributors
			, transactions
			, annualizedAvgContribution::numeric(12,2) annualizedAvgContribution
		from
			trans t
		where
			not exists (select 1 from counts c where c.row_header1 = t.row_header1)
EOS
end

sql << <<-EOS
	)
EOS

	sql << sql_final_select_outputs()

sql << <<-EOS		
	from 
		withtrans c
		left join displaytext d1 on d1.attribute = '#{header1}' and d1.id = c.row_header1
EOS

sql << <<-EOS
	where
		c.a1p_gain <> 0
		or c.a1p_loss <> 0
		or c.paying_gain <> 0
		or c.paying_loss <> 0
		or c.stopped_gain <> 0
		or c.stopped_loss <> 0
		or c.other_gain <> 0
		or c.other_loss <> 0
		or start_count <> 0
		or end_count <> 0
	    or posted <> 0
		or unposted <> 0
	order by
		coalesce(d1.displaytext, c.row_header1)::varchar(200) asc
		--, row_header2
;
EOS

		sql
  end

protected
	def sql_final_select_outputs
    <<-EOS
	select 
		coalesce(d1.displaytext, c.row_header1)::varchar(200) row_header1 -- c.row_header
		--, c.row_header2::varchar(200) row_header2
		, c.row_header1::varchar(20) row_header1_id
		--, ''::varchar(20) row_header2_id
		, c.start_count::int
		, c.a1p_start_count::int
		, c.a1p_gain::int as a1p_real_gain
		, c.a1p_unchanged_gain::int
		, c.a1p_newjoin::int
		, c.a1p_rejoin::int
		, c.a1p_loss::int as a1p_real_loss
		, c.a1p_to_paying::int
		, c.a1p_to_other::int
		, c.a1p_other_gain::int
		, c.a1p_other_loss::int
		, c.a1p_end_count::int
		, c.paying_start_count::int
		, c.paying_gain::int as paying_real_gain
		, c.paying_loss::int as paying_real_loss
		, c.paying_net::int as paying_real_net
		, c.paying_other_gain::int
		, c.paying_other_loss::int
		, c.paying_end_count::int

		, c.stopped_start_count::int
		, c.stopped_gain::int as stopped_real_gain
		, c.stopped_unchanged_gain::int
		, c.rule59_unchanged_gain::int
		, c.stopped_loss::int as stopped_real_loss
		, c.stopped_to_paying::int
		, c.stopped_to_other::int
		, c.stopped_net::int as stopped_real_net
		, c.stopped_other_gain::int
		, c.stopped_other_loss::int
		, c.stopped_end_count::int
-- dbeswick: other_other_gain/loss is returned as other_gain/loss in the SQL function.
		, c.other_other_gain::int other_gain
		, c.other_other_loss::int other_loss
		, c.external_gain::int
		, c.external_loss::int
		, c.net::int
		, c.end_count::int
		, (c.start_count + c.a1p_gain + c.a1p_loss + c.a1p_other_gain+ c.a1p_other_loss + c.paying_gain + c.paying_loss + c.paying_other_gain + c.paying_other_loss + c.stopped_gain + c.stopped_loss + c.stopped_other_gain + c.stopped_other_loss + c.other_other_gain + c.other_other_loss - c.end_count)::int  cross_check
		, c.posted
		, c.unposted
		, c.income_net
		, c.contributors::int
		, c.transactions::int
-- dbeswick: note spelling inconsistency in below column caused by differing name in original SQL 
-- function definition as opposed to column name.
		, c.annualizedavgcontribution annualisedavgcontribution
EOS
	end
end
