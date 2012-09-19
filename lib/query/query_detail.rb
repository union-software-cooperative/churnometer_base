require './lib/query/query_filter'

class QueryDetail < QueryFilter
  def initialize(churn_db, header1, start_date, end_date, with_trans, site_constraint, filter_column, filter_param_hash)
    super(churn_db, filter_param_hash)
    @source = churn_db.fact_table
    @header1 = header1
    @start_date = start_date
    @end_date = end_date
    @with_trans = with_trans
    @site_constraint = site_constraint
    @filter_column = filter_column
  end

  # True if filtering by the given filter column must always require transactions to be disabled.
  def non_transaction_filter_column?(filter_column_name)
    ['contributors',
     'transactions', 
     'income_net', 
     'posted', 
     'unposted'].include?(filter_column_name.downcase) == false
  end

  def self.filter_column_to_where_clause
    @filter_column_to_where_clause ||= {
      'a1p_real_gain' => 'where c.a1p_real_gain<>0',
      'a1p_unchanged_gain' => 'where c.a1p_unchanged_gain<>0',
      'a1p_newjoin' => 'where c.a1p_newjoin<>0',
      'a1p_rejoin' => 'where c.a1p_rejoin<>0',
      'a1p_real_loss' => 'where c.a1p_real_loss<>0',
      'a1p_to_paying' => 'where c.a1p_to_paying>0',
      'a1p_to_other' => 'where c.a1p_to_other<>0',
      'a1p_other_gain' => 'where c.a1p_other_gain<>0',
      'a1p_other_loss' => 'where c.a1p_other_loss<>0',

      'paying_real_gain' => 'where c.paying_real_gain<>0',
      'paying_real_loss' => 'where c.paying_real_loss<>0',
      'paying_real_net' => 'where c.paying_real_net<>0',
      'paying_other_gain' => 'where c.paying_other_gain<>0',
      'paying_other_loss' => 'where c.paying_other_loss<>0',

      'stopped_real_gain' => 'where c.stopped_real_gain<>0',
      'stopped_unchanged_gain' => 'where c.stopped_unchanged_gain<>0',
      'rule59_unchanged_gain' => 'where c.rule59_unchanged_gain<>0',
      'stopped_real_loss' => 'where c.stopped_real_loss<>0',
      'stopped_to_paying' => 'where c.stopped_to_paying<>0',
      'stopped_to_other' => 'where c.stopped_to_other<>0',
      'stopped_other_loss' => 'where c.stopped_other_loss<>0',
      'stopped_other_loss' => 'where c.stopped_other_loss<>0',

      'other_gain' => 'where c.other_other_gain<>0',
      'other_loss' => 'where c.other_other_loss<>0',
      'contributors' => 'where (c.posted<>0 or c.unposted<>0)',
      'income_net' => 'where (c.posted<>0 or c.unposted<>0)',
      'posted' => 'where c.posted<>0',
      'unposted' => 'where c.unposted<>0',
      'transactions' => 'where (c.posted<>0 or c.unposted<>0)',
    }
  end

  def query_string
#CREATE OR REPLACE FUNCTION detail(IN source text, IN header1 text, IN filter_column character varying, IN start_date timestamp without time zone, IN end_date timestamp without time zone, IN with_trans boolean, IN site_constrain text, IN selection xml, OUT memberid character varying, OUT changeid bigint, OUT row_header character varying, OUT row_header_id character varying, OUT a1p_real_gain bigint, OUT a1p_unchanged_gain bigint, OUT a1p_newjoin bigint, OUT a1p_rejoin bigint, OUT a1p_real_loss bigint, OUT a1p_to_paying bigint, OUT a1p_to_other bigint, OUT a1p_other_gain bigint, OUT a1p_other_loss bigint, OUT paying_real_gain bigint, OUT paying_real_loss bigint, OUT paying_real_net bigint, OUT paying_other_gain bigint, OUT paying_other_loss bigint, OUT stopped_real_gain bigint, OUT stopped_unchanged_gain bigint, OUT rule59_unchanged_gain bigint, OUT stopped_real_loss bigint, OUT stopped_to_paying bigint, OUT stopped_to_other bigint, OUT stopped_other_loss bigint, OUT stopped_other_gain bigint, OUT other_gain bigint, OUT other_loss bigint, OUT posted numeric, OUT unposted numeric)

    db = @churn_db.db

    filter = modified_filter_for_site_constraint(filter_terms(), @site_constraint, @start_date, @end_date, @header1)

    non_status_filter = filter.exclude('status', 'statusstaffid')
    user_selections_filter = filter.include('status', 'statusstaffid')

    # Used in the 'trans' block. The statusstaffid filter term should map to the 'staffid' column there.
    trans_statusstaffid_filter = QueryFilterTerms.new
    statusstaffid_remapped_term = filter['statusstaffid'].clone
    statusstaffid_remapped_term.db_column_override = 'staffid'
    trans_statusstaffid_filter.set_term(statusstaffid_remapped_term)

    with_trans = @with_trans && non_transaction_filter_column?(@filter_column) == false

    end_date = @end_date + 1

sql = <<-EOS	
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
			changedate > #{db.sql_date(@start_date)} -- we are not calculating start_counts, so we dont need anything before this date
			#{sql_for_filter_terms(user_selections_filter, true)}
	)
	, nonegations as
	(
		-- removes changes that make no difference to the results or represent gains and losses that cancel out
		select
			*
		from 
			userselections u1
		where
			u1.changeid in (select changeid from userselections u group by changeid having sum(u.net) <> 0) -- any change who has only side in the user selection 
			or u1.changeid in (select changeid from userselections u where payinggain <> 0 or payingloss <> 0 ) -- both sides (if in user selection) if one side is paying and there was a paying change 
 			or u1.changeid in (select changeid from userselections u where a1pgain <> 0 or a1ploss <> 0) -- both sides (if in user selection) if one side is paying and there was a paying change 
 			or u1.#{db.quote_db(@header1 + 'delta')} <> 0 -- unless the changes that cancel out but are transfers between grouped items
 	)
	, trans as
	(
		select 
EOS

sql <<
	if @header1 == 'statusstaffid'
    "			case when coalesce(t.staffid::varchar(200),'') = '' then 'unassigned' else t.staffid::varchar(200) end row_header1"
	else
		"			case when coalesce(u1.#{@header1}::varchar(200),'') = '' then 'unassigned' else u1.#{@header1}::varchar(200) end row_header1"
	end

sql << <<-EOS
		, t.memberid
		, t.changeid
		, sum(case when amount::numeric > 0.0 then amount::numeric else 0.0 end) posted
		, sum(case when amount::numeric < 0.0 then amount::numeric else 0.0 end) unposted
	from
		transactionfact t
		--inner join memberfacthelper u1 on 
		inner join nonstatusselections u1 on
			u1.net = 1 /* state at time of transaction, -1 would be the members prior state */
			and u1.changeid = t.changeid
	where
		t.creationdate > #{db.sql_date(@start_date)}
		and t.creationdate <= #{db.sql_date(end_date)}
		-- statusstaffid is special.  Rather than members and their transactions being assigned to an organising area
		-- statusstaffid is about who actually changed a status or who actually posted the transaction.
		-- for this reason, we filter status staff on staffid field in transactionfact.  
		#{sql_for_filter_terms(trans_statusstaffid_filter, true)}
	group by 
EOS

sql <<
	if @header1 == 'statusstaffid' 
    "		case when coalesce(t.staffid::varchar(200),'') = '' then 'unassigned' else t.staffid::varchar(200) end"
	else
		"		case when coalesce(u1.#{db.quote_db(@header1)}::varchar(200),'') = '' then 'unassigned' else u1.#{db.quote_db(@header1)}::varchar(200) end"
	end

sql << <<-EOS
		, t.changeid
		, t.memberid
)
	, counts as
	(
		-- sum changes, if status doesnt change, then the change is a transfer
		select 
			c.memberid
			, c.changeid::bigint	
			, case when coalesce(#{db.quote_db(@header1)}::varchar(50),'') = '' then 'unassigned' else #{db.quote_db(@header1)}::varchar(50) end row_header
			, a1pgain::bigint a1p_real_gain
			, case when _changeid is null then a1pgain else 0 end::bigint a1p_unchanged_gain
			, case when coalesce(_status, '') = '' then a1pgain else 0 end::bigint a1p_newjoin
			, case when coalesce(_status, '') <> '' then a1pgain else 0 end::bigint a1p_rejoin
			, a1ploss::bigint a1p_real_loss
			, case when coalesce(_status, '') = '1' then a1ploss else 0 end::bigint a1p_to_paying
			, case when coalesce(_status, '') <> '1' then a1ploss else 0 end::bigint a1p_to_other
			, case when coalesce(status, '') = '14' then othergain else 0 end::bigint a1p_other_gain
			, case when coalesce(status, '') = '14' then otherloss else 0 end::bigint a1p_other_loss
			, payinggain::bigint paying_real_gain
			, payingloss::bigint paying_real_loss
			, (payinggain+payingloss)::bigint paying_real_net
			, stoppedgain::bigint stopped_real_gain
			, case when _changeid is null and coalesce(_status,'') = '3' then loss /* only want to count changes too status 3 which will be losses */else 0 end::bigint rule59_unchanged_gain
			, case when _changeid is null then stoppedgain else 0 end::bigint stopped_unchanged_gain
			, stoppedloss::bigint stopped_real_loss
			, case when coalesce(_status,'') = '1' then stoppedloss else 0 end::bigint stopped_to_paying
			, case when coalesce(_status,'') <> '1' then stoppedloss else 0 end::bigint stopped_to_other			
			
			, case when coalesce(status, '') = '1' then othergain else 0 end::bigint paying_other_gain
			, case when coalesce(status, '') = '1' then otherloss else 0 end::bigint paying_other_loss
			, case when coalesce(status, '') = '11' then othergain else 0 end::bigint stopped_other_gain
			, case when coalesce(status, '') = '11' then otherloss else 0 end::bigint stopped_other_loss
			, case when not (status = '1' or status = '14') then othergain else 0 end::bigint other_other_gain
			, case when not (status = '1' or status = '14') then otherloss else 0 end::bigint other_other_loss
			, net::bigint
		from  
			nonegations c
		where
			(
				c.a1pgain <> 0
				or c.a1ploss <> 0
				or c.payinggain <> 0
				or c.payingloss <> 0
				or c.othergain <> 0
				or c.otherloss <> 0
				or c.stoppedgain<>0
				or c.stoppedloss<>0
			)			
	)
	, notrans as
	(
		select 
			*
		from 
			counts c
	)
	, withtrans as
	(
	select
		c.memberid
		, c.changeid
		, c.row_header
		, c.a1p_real_gain
		, c.a1p_unchanged_gain
		, c.a1p_newjoin
		, c.a1p_rejoin
		, c.a1p_real_loss
		, c.a1p_to_paying
		, c.a1p_to_other
		, c.a1p_other_gain
		, c.a1p_other_loss
		, c.paying_real_gain
		, c.paying_real_loss
		, c.paying_real_net
		, c.paying_other_gain
		, c.paying_other_loss
		, c.stopped_real_gain
		, c.stopped_unchanged_gain
		, c.rule59_unchanged_gain
		, c.stopped_real_loss
		, c.stopped_to_paying
		, c.stopped_to_other
		, c.stopped_other_loss
		, c.stopped_other_gain
		, c.other_other_gain
		, c.other_other_loss
EOS

sql << if with_trans
<<-EOS
		, coalesce(t.posted,0)::numeric posted
		, coalesce(t.unposted,0)::numeric unposted
EOS
else
<<-EOS
		, 0::numeric posted
		, 0::numeric unposted
EOS
end

sql << <<-EOS
	from
		notrans c
EOS

if with_trans
  sql << <<-EOS
		left join trans t on c.changeid = t.changeid and c.net = 1
	union all
	select
		t.memberid
		, t.changeid
		, t.row_header1
		, 0::bigint a1p_real_gain
		, 0::bigint a1p_unchanged_gain
		, 0::bigint a1p_newjoin
		, 0::bigint a1p_rejoin
		, 0::bigint a1p_real_loss
		, 0::bigint a1p_to_paying
		, 0::bigint a1p_to_other
		, 0::bigint a1p_other_gain
		, 0::bigint a1p_other_loss
		, 0::bigint paying_real_gain
		, 0::bigint paying_real_loss
		, 0::bigint paying_real_net
		, 0::bigint paying_other_gain
		, 0::bigint paying_other_loss
		, 0::bigint stopped_real_gain
		, 0::bigint stopped_unchanged_gain
		, 0::bigint rule59_unchanged_gain
		, 0::bigint stopped_real_loss
		, 0::bigint stopped_to_paying
		, 0::bigint stopped_to_other
		, 0::bigint stopped_other_loss
		, 0::bigint stopped_other_gain
		, 0::bigint other_other_gain
		, 0::bigint other_other_loss
		, t.posted::numeric posted
		, t.unposted::numeric unposted
	from
		trans t
	where
		t.changeid not in (select changeid from notrans where net = 1)
EOS
end

sql << <<-EOS
)
	select
		c.memberid
		, c.changeid
		, coalesce(d1.displaytext, c.row_header)::varchar(50) row_header -- c.row_header
		, c.row_header::varchar(20) row_header_id
		, c.a1p_real_gain
		, c.a1p_unchanged_gain
		, c.a1p_newjoin
		, c.a1p_rejoin
		, c.a1p_real_loss
		, c.a1p_to_paying
		, c.a1p_to_other
		, c.a1p_other_gain
		, c.a1p_other_loss
		, c.paying_real_gain
		, c.paying_real_loss
		, c.paying_real_net
		, c.paying_other_gain
		, c.paying_other_loss
		, c.stopped_real_gain
		, c.stopped_unchanged_gain
		, c.rule59_unchanged_gain
		, c.stopped_real_loss
		, c.stopped_to_paying
		, c.stopped_to_other
		, c.stopped_other_loss
		, c.stopped_other_gain
		, c.other_other_gain other_gain
		, c.other_other_loss other_loss
		, c.posted
		, c.unposted
	from
		withtrans c
		left join displaytext d1 on d1.attribute = #{db.quote(@header1)} and d1.id = c.row_header
EOS

	# dbeswick: tbd: raise exception on invalid filter column
	sql << self.class.filter_column_to_where_clause()[@filter_column]

sql << <<-EOS
	order by
		c.row_header asc;
EOS

	sql
  end
end
