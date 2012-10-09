require './lib/query/query_filter'

#--
# Should refactor to share a common base class with QuerySummary.
#++
# The 'summary running' query is run when an 'interval' is supplied in the page request.
# The filter view initiates a running total query via the 'Running total' control.
class QuerySummaryRunning < QueryFilter
  # groupby_dimension: An instance of DimensionUser.
  # interval: 'none', 'week' or 'month'
  def initialize(app, churn_db, groupby_dimension, interval, start_date, end_date, with_trans, site_constraint, filter_terms)
    super(app, churn_db, filter_terms)

    if interval.empty?
      raise "Interval must be supplied. Valid values are 'week', 'month', 'quarter', 'year'."
    end

    @groupby_dimension = groupby_dimension
    @header2 = interval
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
	-- 'running summary' query
	with daterange as
	(
		select '2011-08-08'::date + s.t as dates from generate_series(0, ((#{db.sql_date(end_date)}::date)- ('2011-08-08'::date))::int,1) as s(t)
	)
	, nonstatusselections as
	(
		-- finds all changes matching user criteria
		select 
			* 
		from
			#{db.quote_db(source)}
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
 			or u1.#{db.quote_db(header1 + 'delta')} <> 0 -- unless the changes that cancel out but are transfers between grouped items
 	)
, trans as
(
	select 
		case when coalesce(u1.#{header1}::varchar(200),'') = '' then 'unassigned' else u1.#{header1}::varchar(200) end row_header1
		, date_trunc(#{db.quote(@header2)}, creationdate)::date period_header
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
			u1.net = 1 /* state at time of transaction, not the state before transaction */
			and u1.changeid = t.changeid
	where
		t.creationdate > #{db.sql_date(@start_date)}
		and t.creationdate <= #{db.sql_date(end_date)}
	group by 
		case when coalesce(u1.#{header1}::varchar(200),'') = '' then 'unassigned' else u1.#{header1}::varchar(200) end
		, date_trunc(#{db.quote(@header2)}, creationdate)::date 
	)
	, counts as
	(
		-- sum changes, if status doesnt change, then the change is a transfer
		select 
			case when coalesce(#{db.quote_db(header1)}::varchar(200),'') = '' then 'unassigned' else #{db.quote_db(header1)}::varchar(200) end row_header1
			, date_trunc(#{db.quote(@header2)}, case when changedate <= #{db.sql_date(@start_date)} then #{db.sql_date(@start_date)} else changedate end)::date as period_header
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then a1pgain else 0 end) a1p_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and _changeid is null then a1pgain else 0 end) a1p_unchanged_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status, '') = '' then a1pgain else 0 end) a1p_newjoin
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status, '') <>'' then a1pgain else 0 end) a1p_rejoin			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then a1ploss else 0 end) a1p_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status,'') = #{paying_db} then a1ploss else 0 end) a1p_to_paying
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status,'') <> #{paying_db} then a1ploss else 0 end) a1p_to_other			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then payinggain else 0 end) paying_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then payingloss else 0 end) paying_loss
			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then stoppedgain else 0 end) stopped_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and _changeid is null then stoppedgain else 0 end) stopped_unchanged_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then stoppedloss else 0 end) stopped_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status,'') = #{paying_db} then stoppedloss else 0 end) stopped_to_paying
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and coalesce(_status,'') <> #{paying_db} then stoppedloss else 0 end) stopped_to_other			
		
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{a1p_db} then othergain else 0 end) a1p_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{a1p_db} then otherloss else 0 end) a1p_other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{paying_db} then othergain else 0 end) paying_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{paying_db} then otherloss else 0 end) paying_other_loss

			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{stoppedpay_db} then othergain else 0 end) stopped_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and status = #{stoppedpay_db} then otherloss else 0 end) stopped_other_loss			

			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and not (status = #{paying_db} or status = #{a1p_db}) then othergain else 0 end) other_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and not (status = #{paying_db} or status = #{a1p_db}) then otherloss else 0 end) other_other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then othergain else 0 end) other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then otherloss else 0 end) other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and not internalTransfer then othergain else 0 end) external_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} and not internalTransfer then otherloss else 0 end) external_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then a1pgain+a1ploss else 0 end) a1p_net
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then payinggain+payingloss else 0 end) paying_net
			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then stoppedgain+stoppedloss else 0 end) stopped_net
			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then othergain+otherloss else 0 end) other_net
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(end_date)} then coalesce(c.net,0) else 0 end) net
			, sum(net) as end_count
			, sum(case when status = #{a1p_db} then net else 0 end) as a1p_end_count -- cant use a1pgain + a1ploss because they only count when a status changes, where as we want every a1p value in the selection, even if it is a transfer
			, sum(case when status = #{paying_db} then net else 0 end) as paying_end_count
			
			, sum(case when status = #{stoppedpay_db} then net else 0 end) as stopped_end_count
			
		from 
			nonegations c 
		group by 
			case when coalesce(#{db.quote_db(header1)}::varchar(200),'') = '' then 'unassigned' else #{db.quote_db(header1)}::varchar(200) end 
			, date_trunc(#{db.quote(@header2)}, case when changedate <= #{db.sql_date(@start_date)} then #{db.sql_date(@start_date)} else changedate end)::date  
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
			left join trans t on t.row_header1 = c.row_header1 and c.period_header = date_trunc(#{db.quote(@header2)}, (case when t.period_header <= #{db.sql_date(@start_date)} then #{db.sql_date(@start_date)} else t.period_header end))

		union all

		select
			t.row_header1
			, (case when t.period_header < #{db.sql_date(@start_date)} then #{db.sql_date(@start_date)} else t.period_header end) period_header
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
			, 0 stopped_other_net
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
			not exists (select 1 from counts c where c.row_header1 = t.row_header1 and c.period_header = date_trunc(#{db.quote(@header2)}, (case when t.period_header <= #{db.sql_date(@start_date)} then #{db.sql_date(@start_date)} else t.period_header end)))
EOS
end

sql << <<-EOS
	)
	, running_end_counts as 
	(
		select
			c.*
			, case when c.period_header < #{db.sql_date(@start_date)} then #{db.sql_date(@start_date)} else c.period_header end::date as period_start
			, c.period_header + interval '1 #{@header2}' - interval '1 day' as period_end
			, sum(a1p_end_count) over w as running_a1p_end_count
			, sum(paying_end_count) over w as running_paying_end_count
			, sum(stopped_end_count) over w as running_stopped_end_count
			, sum(end_count) over w as running_end_count
			, sum(a1p_gain + a1p_loss) over w  as running_a1p_net
			, sum(paying_gain + paying_loss) over w  as running_paying_net
			, sum(stopped_gain + stopped_loss) over w  as running_stopped_net
			, sum(a1p_gain + a1p_loss + paying_gain + paying_loss) over w  as running_net

		from
			withtrans c
		window w as (
			partition by row_header1 order by c.period_header
		)
	)
	, running_start_counts as
	(
		select
			c.row_header1
			, c.period_start as period_header
			, c.period_start
			, case when c.period_end > #{db.sql_date(end_date)} then #{db.sql_date(end_date)} else c.period_end end period_end
			, c.running_a1p_net
			, c.running_paying_net
			, c.running_net
			, c.running_end_count - c.a1p_gain - c.a1p_loss - c.a1p_other_gain - c.a1p_other_loss - c.paying_gain - c.paying_loss - c.paying_other_gain - c.paying_other_loss - c.other_other_gain - c.other_other_loss as start_count
			, c.running_a1p_end_count - c.a1p_gain - c.a1p_loss - c.a1p_other_gain - c.a1p_other_loss as a1p_start_count
			, c.a1p_gain
			, c.a1p_unchanged_gain
			, c.a1p_newjoin	
			, c.a1p_rejoin
			, c.a1p_loss
			, c.a1p_to_paying
			, c.a1p_to_other
			, c.a1p_other_gain
			, c.a1p_other_loss
			, c.running_a1p_end_count a1p_end_count

			, c.running_paying_end_count - c.paying_gain - c.paying_loss - c.paying_other_gain - c.paying_other_loss as paying_start_count
			, c.paying_gain
			, c.paying_loss
			, c.paying_net
			, c.paying_other_gain
			, c.paying_other_loss
			, c.running_paying_end_count paying_end_count

			, c.running_stopped_end_count - c.stopped_gain - c.stopped_loss - c.stopped_other_gain - c.stopped_other_loss as stopped_start_count
			, c.stopped_gain
			, c.stopped_unchanged_gain
			, c.stopped_loss
			, c.stopped_to_paying
			, c.stopped_to_other
			, c.stopped_net
			, c.stopped_other_gain
			, c.stopped_other_loss
			, c.running_stopped_end_count stopped_end_count

			, c.other_other_gain 
			, c.other_other_loss 
			, c.external_gain
			, c.external_loss
			, c.net
			, c.running_end_count end_count
			, c.posted
			, c.unposted
			, c.income_net
			, c.contributors
			, c.transactions
			, c.annualizedavgcontribution
		from
			running_end_counts c
	)
	select 
		coalesce(d1.displaytext, c.row_header1)::varchar(200) row_header1 -- c.row_header
		, c.row_header1::varchar(20) row_header1_id
		, (c.period_header::varchar(20) || ' - ' || #{db.quote(@header2)} || ' ' || extract(#{db.quote(@header2)} from c.period_header)::varchar(2))::varchar(200) as period_header
		, c.running_a1p_net::bigint
		, c.running_paying_net::bigint
		, c.running_net::bigint
		, period_start::date
		, period_end::date
		, c.start_count::bigint
		, c.a1p_start_count::bigint
		, c.a1p_gain as a1p_real_gain
		, c.a1p_unchanged_gain
		, c.a1p_newjoin
		, c.a1p_rejoin
		, c.a1p_loss as a1p_real_loss
		, c.a1p_to_paying
		, c.a1p_to_other
		, c.a1p_other_gain
		, c.a1p_other_loss
		, c.a1p_end_count::bigint
		
		, c.paying_start_count::bigint
		, c.paying_gain as paying_real_gain
		, c.paying_loss as paying_real_loss
		, c.paying_net as paying_real_net
		, c.paying_other_gain
		, c.paying_other_loss 
		, c.paying_end_count::bigint

		, c.stopped_start_count::bigint
		, c.stopped_gain stopped_real_gain
		, c.stopped_unchanged_gain
		, c.stopped_loss stopped_real_loss
		, c.stopped_to_paying
		, c.stopped_to_other
		, c.stopped_net
		, c.stopped_other_gain
		, c.stopped_other_loss
		, c.stopped_end_count::bigint

		, c.other_other_gain other_gain
		, c.other_other_loss other_loss
		, c.external_gain
		, c.external_loss
		, c.net
		, c.end_count::bigint
		, (c.start_count + c.a1p_gain + c.a1p_loss + c.a1p_other_gain+ c.a1p_other_loss + c.paying_gain + c.paying_loss + c.paying_other_gain + c.paying_other_loss + c.other_other_gain + c.other_other_loss - c.end_count)::bigint  cross_check
		, c.posted
		, c.unposted
		, c.income_net
		, c.contributors
		, c.transactions
		, c.annualizedavgcontribution annualisedavgcontribution
EOS

sql << <<-EOS
	from 
		running_start_counts c
		left join displaytext d1 on d1.attribute = #{db.quote(header1)} and d1.id = c.row_header1
EOS

sql << <<-EOS
	where
		c.a1p_gain <> 0
		or c.a1p_loss <> 0
		or c.paying_gain <> 0
		or c.paying_loss <> 0
		or c.stopped_gain <> 0
		or c.stopped_loss <> 0
		or c.other_other_gain <> 0
		or c.other_other_loss <> 0
		or start_count <> 0
		or end_count <> 0
		or posted <> 0 
		or unposted <> 0
	order by
		coalesce(d1.displaytext, c.row_header1)::varchar(200) asc
		, c.period_header
EOS

		sql
	end
end
