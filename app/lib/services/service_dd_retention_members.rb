require './lib/services/service_autocomplete'

class ServiceDDRetentionMembers < ServiceAutocomplete
  def initialize(churn_db, churnometer_app, param_hash)
    super

    startdate = param_hash['startdate']
    enddate = param_hash['enddate']
    branchid = param_hash['branchid']
    status = param_hash['status']
    column = param_hash['column']

    raise "No startdate supplied." if startdate.nil?
    raise "No enddate supplied." if enddate.nil?
    raise "No column supplied." if column.nil?

    @query = sql_text(startdate, enddate, branchid, column, status)
  end

  protected
  def json_to_db_column_mapping
    {
      "memberid" => "memberid",
    }
  end

  def sql_text(periodstartdate, periodenddate, branchid, column, status)

   unless branchid.nil?
      branch_where = <<-WHERE
          branchid = '#{branchid}'
      WHERE
    else
      branch_where = "1=1"
    end

    <<-SQL
with userselections as (
	select
		*
	from
		memberfacthelper
	where
		(
			paymenttypeid in ('d', 'c', 'r', 'w')
		)
		and
		(
			status in ('11', '14', '23', '24', '25')
		)
		and
		(
			#{branch_where}
		)
)
, statuschanges as (
	select * from memberfact where coalesce(newstatus, '') <> coalesce(oldstatus, '')
)
, sc as (
    --select *, lead(changedate) over (partition by memberid order by changeid) nextstatuschangedate from statuschanges -- attempting to get next status change so I can get end counts not by summing
	select * from memberfact where coalesce(newstatus, '') <> coalesce(oldstatus, '')
)
, problems as (
        select
			*
		from
			sc
		where
			newstatus in ('14', '11', '23', '24', '25')
			and (not oldstatus in ('14', '11', '23', '24', '25') or oldstatus is null)
			and sc.changedate::date < '#{periodenddate}' -- problem started before user's search end (exclude problems on or after user's enddate)

), resolutions as (
	select
		*
	from
		sc
	where
		(not newstatus in ('14', '11', '23', '24', '25') or newstatus is null)
		and oldstatus in ('14', '11', '23', '24', '25')
)
, problem_interval as (
	select
		*
	from
		(
			select
				row_number() over (partition by p.changeid order by r.changedate) rank1
				, p.memberid
				, p.changeid problemchangeid
				, p.changedate problemchangedate
				, p.newstatus problemstatus
				, r.changeid as resolutionchangeid
				, r.changedate as resolutionchangedate
				, r.newstatus as resolutionstatus
			from
				problems p
				left join resolutions r on p.memberid = r.memberid and r.changedate > p.changedate
		) asdf
	where
		rank1 = 1 -- select the earliest resolution for a problem
		-- resolution occurs on or after the user's search start or there is no resolution
		-- i.e. exclude problems that a resolved prior to user's search start
		and (resolutionchangedate::date >= '#{periodstartdate}' or resolutionchangedate is null)
)
, problem_interval_retained_until as (
        select
                *
        from
                (
                        select
							p.*
							, rank() over (partition by p.problemchangeid order by s.changedate) rank2
							, s.changeid relapsechangeid
							, s.changedate relapsechangedate
							, s.newstatus relapsestatus
                        from
                                problem_interval p
                                left join (select * from sc where newstatus <> '1'/* and newstatus <> '14'*/) s on p.resolutionstatus = '1' and p.memberid = s.memberid and s.changedate > p.resolutionchangedate
                ) ranked
        where
                rank2 = 1
)
, problem_interal_amount_retained as (
        select
                *
                , (select sum(amount) from transactionfact t where r.resolutionstatus = '1' and t.memberid = r.memberid and t.creationdate >= r.resolutionchangedate and (t.creationdate < r.relapsechangedate or r.relapsechangedate is null)) amount --between r.resolutionchangedate and r.relapsechangedate) amount
        from
                problem_interval_retained_until  r
)
, changes as (
	-- Join all relevant changes for each problem - there maybe several status changes while resolving a payment issue
	select
		u.*
		, p.problemchangeid
		, p.problemchangedate
		, p.problemstatus
		, p.resolutionchangeid
		, p.resolutionchangedate
		, p.resolutionstatus
		, p.relapsechangeid
		, p.relapsechangedate
		, p.relapsestatus
		, p.amount
	from
		userselections u
		inner join problem_interal_amount_retained p on u.memberid = p.memberid and u.changeid >= p.problemchangeid and (u.changeid <= p.resolutionchangeid or p.resolutionchangeid is null)
	where
		-- I'm guessing I need these as well as the filters on the problems
		(
			-- exclude changes that occur on or after the user's enddate
			u.changedate::date < '#{periodenddate}'::date
		)
		and (
			u.changedate::date >= '#{periodstartdate}'::date -- include changes that occur on or after the user's start date
			-- include the change immediately prior to the user's start date to get the initial state for each member
			or (u.net = 1 and changedate::date < '#{periodstartdate}'::date and nextchangedate::date >= '#{periodstartdate}'::date)
		)
)
, transfers as (
	select changeid, sum(net) from changes group by changeid having sum(net) <> 0  -- any change with a non zero sum(net) has a before or after state that doesn't fall inside the user selection set, therefore a transfer in or out
)
, changesthatmatter as (
select
	case when t.changeid is null or c.status <> c._status then 0 else 1 end set_transfer
	, case when c._status in ('11', '14', '23', '24', '25') and c.status in ('11', '14', '23', '24', '25') and c.status <> c._status then 1 else 0 end status_transfer
	, c.*
	, row_number() over (partition by c.problemchangeid order by c.changeid) status_change_rank
	, row_number() over (partition by c.problemchangeid order by c.changeid desc) status_change_rank_reversed
from
	changes c
	left join transfers t on t.changeid = c.changeid
where
	(
		not t.changeid is null -- any change that is a transfer in or out
		or c.status <> c._status -- any status change ( a change between status groupings within the selection set)
	)
	and c.status in ('11', '14', '23', '24', '25')
)

, detail as (
select

	case when net = 1 and changedate::date < '#{periodstartdate}'::date and nextchangedate::date >= '#{periodstartdate}' then net else 0 end problems_at_start
	, case when net = 1 and changedate::date < '#{periodstartdate}'::date and nextchangedate::date >= '#{periodstartdate}' and (resolutionchangedate is null or resolutionchangedate::date >= '#{periodenddate}') then 1 else 0 end unresolved_since_start
	, case when net = 1 and changedate::date >= '#{periodstartdate}'::date and changedate::date < '#{periodenddate}' and not (set_transfer = 1 or status_transfer = 1) then 1 else 0 end new_problems
	, case when net = 1 and changedate::date >= '#{periodstartdate}'::date and changedate::date < '#{periodenddate}' and (set_transfer = 1 or status_transfer = 1) then 1 else 0 end transfers_in
	, case when net = -1 and changedate::date >= '#{periodstartdate}'::date and changedate::date < '#{periodenddate}' and (set_transfer = 1 or status_transfer = 1) then 1 else 0 end transfers_out

	, case when changeid = resolutionchangeid and coalesce(resolutionstatus,'') <> '1' and not resolutionchangeid is null and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' then 1 else 0 end resolved_badly
	, case when changeid = resolutionchangeid and coalesce(resolutionstatus,'') <> '1' and not resolutionchangeid is null and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' then extract(day from resolutionchangedate - problemchangedate)::int else 0 end resolved_badly_days

	, case when changeid = resolutionchangeid and resolutionstatus = '1' and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' then 1 else 0 end resolved_well
	, case when changeid = resolutionchangeid and resolutionstatus = '1' and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' and relapsestatus is null then 1 else 0 end resolved_well_still_paying
	, case when changeid = resolutionchangeid and resolutionstatus = '1' and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' and not relapsestatus is null then 1 else 0 end resolved_well_not_still_paying
	, case when changeid = resolutionchangeid and resolutionstatus = '1' and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' then extract(day from resolutionchangedate - problemchangedate)::int else 0 end resolved_well_days

	, case when changeid = resolutionchangeid and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' then amount else 0::money end as amount_retained
	--, case when status_change_rank = 1 and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' then amount else 0::money end as amount_retained_with_problem
	--, case when status_change_rank_reversed = 1 and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' then amount else 0::money end as amount_retained_with_resolution2
	--, case when problemstatus = status and changeid = resolutionchangeid and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' then amount else 0::money end resolved_well_amount
	--, case when problemstatus <> status and changeid = resolutionchangeid and resolutionchangedate::date >= '#{periodstartdate}' and resolutionchangedate::date < '#{periodenddate}' then amount else 0::money end resolved_well_transfered_in_amount

	, case when net = 1 and changedate::date < '#{periodenddate}'::date and _changedate::date >= '#{periodenddate}' then net else 0 end problems_at_end
	, changesthatmatter.*
from
	changesthatmatter
)
select memberid from detail where (status = '#{status}' or '#{status}' = '') and #{column} <> 0
    SQL
  end
end
