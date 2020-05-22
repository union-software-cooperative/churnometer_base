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

    paying_db = db.sql_array(@app.paying_statuses)
    a1p_db = db.sql_array(@app.a1p_statuses)
    stoppedpay_db = db.sql_array(@app.stopped_statuses)
    waiver_db = db.sql_in(@app.waiver_statuses)

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
          (
            changedate < #{db.sql_date(end_date)} -- Everything after enddate can be ignored.
            and nextchangedate >= #{db.sql_date(@start_date)} -- all changes that ended after startdate
            and (changedate >= #{db.sql_date(@start_date)} or net = 1) -- all changes that occurred after startdate OR all after changes that occurred before startdate
          )
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
      , transfersin as
      (
        select changeid from userselections u group by changeid having sum(u.net) <> 0
      )
      , statuschanges as
      (
        select distinct changeid from userselections u where payinggain <> 0 or payingloss <> 0 or a1pgain <> 0 or a1ploss <> 0 or stoppedgain <> 0 or stoppedloss <> 0 or waivergain <> 0 or waivergain <> 0
      )
      , nonegations as
      (
        -- removes changes that make no difference to the results or represent gains and losses that cancel out
        select
          u1.*
          , case when transfersin.changeid is not null then 1 else 0 end set_transfer
          , case when transfersin.changeid is not null then false else true end internaltransfer
          , case when statuschanges.changeid is not null then 1 else 0 end statuschange
          , case when #{header1 == 'userid' ? '1=0' : "u1.#{header1}delta <> 0" } then 1 else 0 end  group_transfer
        from
          userselections u1
          left join transfersin on u1.changeid = transfersin.changeid --and u1.net = transfersin.net
          left join statuschanges on u1.changeid = statuschanges.changeid --and u1.net = statuschanges.net
        where
          transfersin.changeid is not null
          or statuschanges.changeid is not null
          #{header1 == 'userid' ? '' : "or u1.#{header1}delta <> 0" }
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
        t.creationdate >= #{db.sql_date(@start_date)}
        and t.creationdate < #{db.sql_date(end_date)}
      group by
        case when coalesce(u1.#{header1}::varchar(200),'') = '' then 'unassigned' else u1.#{header1}::varchar(200) end
        , date_trunc(#{db.quote(@header2)}, creationdate)::date
      )
      , counts as
      (
        -- sum changes, if status doesnt change, then the change is a transfer
        select
          case when coalesce(#{db.quote_db(header1)}::varchar(200),'') = '' then 'unassigned' else #{db.quote_db(header1)}::varchar(200) end row_header1
          , date_trunc(#{db.quote(@header2)}, case when changedate < #{db.sql_date(@start_date)} then #{db.sql_date(@start_date)} else changedate end)::date as period_header

          /* SHARED BETWEEEN SUMMARY AND RUNNING SUMMARY - TODO REFACTOR */
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then a1pgain else 0 end) a1p_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then a1ploss else 0 end) a1p_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then payinggain else 0 end) paying_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then payingloss else 0 end) paying_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then stoppedgain else 0 end) stopped_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then stoppedloss else 0 end) stopped_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then waivergain else 0 end) waiver_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then waivergaingood else 0 end) waiver_gain_good
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then waivergainbad else 0 end) waiver_gain_bad
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then waiverloss else 0 end) waiver_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then waiverlossgood else 0 end) waiver_loss_good
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then waiverlossbad else 0 end) waiver_loss_bad
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then othergain else 0 end) other_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then otherloss else 0 end) other_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then membergain else 0 end) member_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then memberloss else 0 end) member_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then greengain else 0 end) green_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then greenloss else 0 end) green_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then greengain_nonmember else 0 end) green_gain_nonmember
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then greenloss_nonmember else 0 end) green_loss_nonmember
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then greengain_member else 0 end) green_gain_member
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then greenloss_member else 0 end) green_loss_member
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then orangegain else 0 end) orange_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then orangeloss else 0 end) orange_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then orangegain_nonmember else 0 end) orange_gain_nonmember
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then orangeloss_nonmember else 0 end) orange_loss_nonmember
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then orangegain_member else 0 end) orange_gain_member
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then orangeloss_member else 0 end) orange_loss_member

          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and status = ANY (#{a1p_db}) then othergain else 0 end) a1p_other_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and status = ANY (#{a1p_db}) then otherloss else 0 end) a1p_other_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and status = ANY (#{paying_db}) then othergain else 0 end) paying_other_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and status = ANY (#{paying_db}) then otherloss else 0 end) paying_other_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and status = ANY (#{stoppedpay_db}) then othergain else 0 end) stopped_other_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and status = ANY (#{stoppedpay_db}) then otherloss else 0 end) stopped_other_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and waivernet <> 0 then othergain else 0 end) waiver_other_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and waivernet <> 0 then otherloss else 0 end) waiver_other_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and not (status = ANY (#{paying_db}) or status = ANY (#{a1p_db}) or status = ANY (#{stoppedpay_db}) or waivernet <> 0) then othergain else 0 end) other_other_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and not (status = ANY (#{paying_db}) or status = ANY (#{a1p_db}) or status = ANY (#{stoppedpay_db}) or waivernet <> 0) then otherloss else 0 end) other_other_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and (set_transfer = 1 or group_transfer = 1) then othermembergain else 0 end) member_other_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and (set_transfer = 1 or group_transfer = 1) then othermemberloss else 0 end) member_other_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and (set_transfer = 1 or group_transfer = 1) then othergreengain else 0 end) green_other_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and (set_transfer = 1 or group_transfer = 1) then othergreenloss else 0 end) green_other_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and (set_transfer = 1 or group_transfer = 1) then otherorangegain else 0 end) orange_other_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and (set_transfer = 1 or group_transfer = 1) then otherorangeloss else 0 end) orange_other_loss

          , sum(a1pnet) as a1p_end_count -- cant use a1pgain + a1ploss because they only count when a status changes, where as we want every a1p value in the selection, even if it is a transfer
          , sum(payingnet) as paying_end_count
          , sum(stoppednet) as stopped_end_count
          , sum(waivernet) as waiver_end_count
          , sum(othernet) as other_end_count
          , sum(membernet) as member_end_count
          , sum(greennet) as green_end_count
          , sum(orangenet) as orange_end_count
          , sum(net) as end_count

          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then a1pgain+a1ploss else 0 end) a1p_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then payinggain+payingloss else 0 end) paying_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then stoppedgain+stoppedloss else 0 end) stopped_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then waivergain + waiverloss else 0 end) waiver_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then othergain+otherloss else 0 end) other_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then membergain + memberloss else 0 end) member_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then greengain + greenloss else 0 end) green_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then orangegain + orangeloss else 0 end) orange_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then coalesce(c.net,0) else 0 end) net

          -- Odd non standard columns
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and _categorychangeid is null then a1pgain else 0 end) a1p_unchanged_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and coalesce(_status, '') = '' then a1pgain else 0 end) a1p_newjoin
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and coalesce(_status, '') <>'' then a1pgain else 0 end) a1p_rejoin
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and coalesce(_status,'') = ANY (#{paying_db}) then a1ploss else 0 end) a1p_to_paying
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and not coalesce(_status,'') = ANY (#{paying_db}) then a1ploss else 0 end) a1p_to_other
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and coalesce(_status,'') = ANY (#{paying_db}) then stoppedloss else 0 end) stopped_to_paying
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and not coalesce(_status,'') = ANY (#{paying_db}) then stoppedloss else 0 end) stopped_to_other
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and _categorychangeid is null then stoppedgain else 0 end) stopped_unchanged_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and not internalTransfer then othergain else 0 end) external_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and not internalTransfer then otherloss else 0 end) external_loss
          /* EO SHARED BETWEEEN SUMMARY AND RUNNING SUMMARY - TODO REFACTOR */


      from
          nonegations c
        group by
          case when coalesce(#{db.quote_db(header1)}::varchar(200),'') = '' then 'unassigned' else #{db.quote_db(header1)}::varchar(200) end
          , date_trunc(#{db.quote(@header2)}, case when changedate < #{db.sql_date(@start_date)} then #{db.sql_date(@start_date)} else changedate end)::date
      )
      , withtrans as
      (
        select
          c.*
    EOS

    sql << if @with_trans
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

    sql << <<-EOS
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
          , 0 a1p_loss
          , 0 paying_gain
          , 0 paying_loss
          , 0 stopped_gain
          , 0 stopped_loss
          , 0 waiver_gain
          , 0 waiver_loss
          , 0 waiver_gain_good
          , 0 waiver_gain_bad
          , 0 waiver_loss_good
          , 0 waiver_loss_bad
          , 0 other_gain
          , 0 other_loss
          , 0 member_gain
          , 0 member_loss
          , 0 green_gain
          , 0 green_loss
          , 0 green_gain_nonmember
          , 0 green_loss_nonmember
          , 0 green_gain_member
          , 0 green_loss_member
          , 0 orange_gain
          , 0 orange_loss
          , 0 orange_gain_nonmember
          , 0 orange_loss_nonmember
          , 0 orange_gain_member
          , 0 orange_loss_member

          , 0 a1p_other_gain
          , 0 a1p_other_loss
          , 0 paying_other_gain
          , 0 paying_other_loss
          , 0 stopped_other_gain
          , 0 stopped_other_loss
          , 0 waiver_other_gain
          , 0 waiver_other_loss
          , 0 other_other_gain
          , 0 other_other_loss
          , 0 member_other_gain
          , 0 member_other_loss
          , 0 green_other_gain
          , 0 green_other_loss
          , 0 orange_other_gain
          , 0 orange_other_loss

          , 0 a1p_end_count
          , 0 paying_end_count
          , 0 stopped_end_count
          , 0 waiver_end_count
          , 0 other_end_count
          , 0 member_end_count
          , 0 green_end_count
          , 0 orange_end_count
          , 0 end_count

          , 0 a1p_net
          , 0 paying_net
          , 0 stopped_net
          , 0 waiver_net
          , 0 other_net
          , 0 member_net
          , 0 green_net
          , 0 orange_net
          , 0 net

          -- odd columns
          , 0 a1p_unchanged_gain
          , 0 a1p_newjoin
          , 0 a1p_rejoin
          , 0 a1p_to_paying
          , 0 a1p_to_other
          , 0 stopped_to_paying
          , 0 stopped_to_other
          , 0 stopped_unchanged_gain
          , 0 external_gain
          , 0 external_loss

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
          , sum(end_count) over w as running_end_count
          , sum(a1p_end_count) over w as running_a1p_end_count
          , sum(paying_end_count) over w as running_paying_end_count
          , sum(stopped_end_count) over w as running_stopped_end_count
          , sum(waiver_end_count) over w as running_waiver_end_count
          , sum(member_end_count) over w as running_member_end_count
          , sum(green_end_count) over w as running_green_end_count
          , sum(orange_end_count) over w as running_orange_end_count

          , sum(a1p_gain + a1p_loss) over w  as running_a1p_net
          , sum(paying_gain + paying_loss) over w  as running_paying_net
          , sum(stopped_gain + stopped_loss) over w  as running_stopped_net
          , sum(waiver_gain + waiver_loss) over w  as running_waiver_net
          , sum(member_gain + member_loss) over w  as running_member_net
          , sum(green_gain + green_loss) over w  as running_green_net
          , sum(orange_gain + orange_loss) over w  as running_orange_net
          , sum(a1p_gain + a1p_loss + paying_gain + paying_loss + stopped_gain + stopped_loss + waiver_gain + waiver_loss) over w  as running_net

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
          , c.running_stopped_net
          , c.running_waiver_net
          , c.running_member_net
          , c.running_green_net
          , c.running_orange_net
          , c.running_net

          , c.running_end_count - c.a1p_gain - c.a1p_loss - c.a1p_other_gain - c.a1p_other_loss - c.paying_gain - c.paying_loss - c.paying_other_gain - c.paying_other_loss - c.other_other_gain - c.other_other_loss - c.waiver_gain - c.waiver_loss - c.waiver_other_gain - c.waiver_other_loss - c.stopped_other_gain - c.stopped_other_loss - c.stopped_gain - c.stopped_loss as start_count
          , c.running_a1p_end_count - c.a1p_gain - c.a1p_loss - c.a1p_other_gain - c.a1p_other_loss as a1p_start_count
          , c.a1p_gain
          , c.a1p_unchanged_gain
          , c.a1p_newjoin
          , c.a1p_rejoin
          , c.a1p_loss
          , c.a1p_net
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
          , c.stopped_net
          , c.stopped_to_paying
          , c.stopped_to_other
          , c.stopped_other_gain
          , c.stopped_other_loss
          , c.running_stopped_end_count stopped_end_count

          , c.running_waiver_end_count - c.waiver_gain - c.waiver_loss - c.waiver_other_gain - c.waiver_other_loss as waiver_start_count
          , c.waiver_gain as waiver_real_gain
          , c.waiver_loss as waiver_real_loss
          , c.waiver_gain_good as waiver_real_gain_good
          , c.waiver_gain_bad as waiver_real_gain_bad
          , c.waiver_loss_good as waiver_real_loss_good
          , c.waiver_loss_bad as waiver_real_loss_bad
          , c.waiver_net
          , c.waiver_other_gain
          , c.waiver_other_loss
          , c.running_waiver_end_count as waiver_end_count

          , c.running_member_end_count - c.member_gain - c.member_loss - c.member_other_gain - c.member_other_loss as member_start_count
          , c.member_gain as member_real_gain
          , c.member_loss as member_real_loss
          , c.member_net as member_real_net
          , c.member_other_gain
          , c.member_other_loss
          , c.running_member_end_count as member_end_count

          , c.running_green_end_count - c.green_gain - c.green_loss - c.green_other_gain - c.green_other_loss as green_start_count
          , c.green_gain as green_real_gain
          , c.green_gain_nonmember as green_real_gain_nonmember
          , c.green_gain_member as green_real_gain_member
          , c.green_loss as green_real_loss
          , c.green_loss_nonmember as green_real_loss_nonmember
          , c.green_loss_member as green_real_loss_member
          , c.green_net as green_real_net
          , c.green_other_gain
          , c.green_other_loss
          , c.running_green_end_count as green_end_count

          , c.running_orange_end_count - c.orange_gain - c.orange_loss - c.orange_other_gain - c.orange_other_loss as orange_start_count
          , c.orange_gain as orange_real_gain
          , c.orange_gain as orange_real_gain_nonmember
          , c.orange_gain as orange_real_gain_member
          , c.orange_loss as orange_real_loss
          , c.orange_loss as orange_real_loss_nonmember
          , c.orange_loss as orange_real_loss_member
          , c.orange_net as orange_real_net
          , c.orange_other_gain
          , c.orange_other_loss
          , c.running_orange_end_count as orange_end_count

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
        , c.row_header1::varchar(200) row_header1_id
        , (c.period_header::varchar(20) || ' - ' || #{db.quote(@header2)} || ' ' || extract(#{db.quote(@header2)} from c.period_header)::varchar(2))::varchar(200) as period_header
        , c.running_a1p_net::bigint
        , c.running_paying_net::bigint
        , c.running_stopped_net::bigint
        , c.running_waiver_net::bigint
        , c.running_member_net::bigint
        , c.running_green_net::bigint
        , c.running_orange_net::bigint
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
        , c.a1p_net::int as a1p_real_net
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
        , c.stopped_net::int as stopped_real_net
        , c.stopped_to_paying
        , c.stopped_to_other
        , c.stopped_other_gain
        , c.stopped_other_loss
        , c.stopped_end_count::bigint

        , c.waiver_start_count::int
        , c.waiver_real_gain
        , c.waiver_real_loss
        , c.waiver_real_gain_good
        , c.waiver_real_gain_bad
        , c.waiver_real_loss_good
        , c.waiver_real_loss_bad
        , c.waiver_net::int
        , c.waiver_other_gain::int
        , c.waiver_other_loss::int
        , c.waiver_end_count::int

        , c.member_start_count::int
        , c.member_real_gain
        , c.member_real_loss
        , c.member_real_net
        , c.member_other_gain::int
        , c.member_other_loss::int
        , c.member_end_count::int

        , c.green_start_count::int
        , c.green_real_gain
        , c.green_real_gain_nonmember
        , c.green_real_gain_member
        , c.green_real_loss
        , c.green_real_loss_nonmember
        , c.green_real_loss_member
        , c.green_real_net
        , c.green_other_gain::int
        , c.green_other_loss::int
        , c.green_end_count::int

        , c.orange_start_count::int
        , c.orange_real_gain
        , c.orange_real_gain_nonmember
        , c.orange_real_gain_member
        , c.orange_real_loss
        , c.orange_real_loss_nonmember
        , c.orange_real_loss_member
        , c.orange_real_net
        , c.orange_other_gain::int
        , c.orange_other_loss::int
        , c.orange_end_count::int

        , c.other_other_gain other_gain
        , c.other_other_loss other_loss
        , c.external_gain
        , c.external_loss

        , c.net
        , c.end_count::bigint
        , ( case when 0 <> c.member_start_count + c.member_real_gain + c.member_real_loss + c.member_other_gain + c.member_other_loss - c.member_end_count then 'member' else '' end)
          || ( case when 0 <> c.start_count + c.a1p_gain + c.a1p_loss + c.a1p_other_gain + c.a1p_other_loss + c.paying_gain + c.paying_loss + c.paying_other_gain + c.paying_other_loss + c.stopped_gain + c.stopped_loss + c.stopped_other_gain + c.stopped_other_loss + c.waiver_real_gain + c.waiver_real_loss + c.waiver_other_gain + c.waiver_other_loss + c.other_other_gain + c.other_other_loss - c.end_count then ' total' else '' end)
          || ( case when 0 <> c.a1p_start_count + c.a1p_gain + c.a1p_loss + c.a1p_other_gain + c.a1p_other_loss - c.a1p_end_count then ' a1p' else '' end)
          || ( case when 0 <> c.paying_start_count + c.paying_gain + c.paying_loss + c.paying_other_gain + c.paying_other_loss - c.paying_end_count then ' paying' else '' end)
          || ( case when 0 <> c.stopped_start_count + c.stopped_gain + c.stopped_loss + c.stopped_other_gain + c.stopped_other_loss - c.stopped_end_count then ' stopped' else '' end)
          || ( case when 0 <> c.waiver_start_count + c.waiver_real_gain + c.waiver_real_loss + c.waiver_other_gain + c.waiver_other_loss - c.waiver_end_count then ' waiver' else '' end)
          || ( case when 0 <> c.orange_start_count + c.orange_real_gain + c.orange_real_loss + c.orange_other_gain + c.orange_other_loss - c.orange_end_count then ' orange' else '' end)
          || ( case when 0 <> c.green_start_count + c.green_real_gain + c.green_real_loss + c.green_other_gain + c.green_other_loss - c.green_end_count then ' green' else '' end)
          || ( case when 0 <> c.a1p_start_count + c.paying_start_count + c.stopped_start_count + c.waiver_start_count - c.member_start_count then ' start count' else '' end)
          || ( case when 0 <> c.a1p_end_count + c.paying_end_count + c.stopped_end_count + c.waiver_end_count - c.member_end_count then ' end count' else '' end)
          || ( case when 0 <> c.green_start_count + c.orange_start_count - c.member_start_count then ' contributor start count' else '' end)
          || ( case when 0 <> c.green_end_count + c.orange_end_count - c.member_end_count then ' contributor end count' else '' end)
          as cross_check
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
        or c.waiver_real_gain <> 0
        or c.waiver_real_loss <> 0
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
