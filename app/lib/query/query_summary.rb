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
    trans_header1 = header1 == 'userid' ? 't.userid' : "u1.#{header1}" # join on transactionfact's userid (transaction poster) rather than memberfact's userid (member [status] editor)

    filter = modified_filter_for_site_constraint(filter_terms(), @site_constraint, @start_date, @end_date)

    non_status_filter = filter.exclude('status')
    user_selections_filter = filter.include('status')

    end_date = @end_date + 1

    paying_db = db.sql_array(@app.paying_statuses)
    a1p_db = db.sql_array(@app.a1p_statuses)
    stoppedpay_db = db.sql_array(@app.stopped_statuses)
    exiting_db = db.sql_array(@app.exiting_statuses)

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
        select distinct changeid from userselections u where payinggain <> 0 or payingloss <> 0 or a1pgain <> 0 or a1ploss <> 0 or stoppedgain <> 0 or stoppedloss <> 0 or exitinggain <> 0 or exitingloss <> 0 or waivergain <> 0 or waiverloss <> 0
      )
      , nonegations as
      (
        -- removes changes that make no difference to the results or represent gains and losses that cancel out
        select
          u1.*
          , case when transfersin.changeid is not null then 1 else 0 end set_transfer
          , case when transfersin.changeid is not null then false else true end internaltransfer
          , case when statuschanges.changeid is not null then 1 else 0 end statuschange
          , case when #{"u1.#{header1}delta <> 0"} then 1 else 0 end group_transfer
        from
          userselections u1
          left join transfersin on u1.changeid = transfersin.changeid --and u1.net = transfersin.net
          left join statuschanges on u1.changeid = statuschanges.changeid --and u1.net = statuschanges.net
        where
          transfersin.changeid is not null
          or statuschanges.changeid is not null
          #{"or u1.#{header1}delta <> 0"}
       )
       /*
      , nonegations as
      (
        -- removes changes that make no difference to the results or represent gains and losses that cancel out
        select
          *, case when u1.changeid in (select changeid from userselections u group by changeid having sum(u.net) <> 0) then false else true end internalTransfer
        from
          userselections u1
        where
          u1.changeid in (select changeid from userselections u group by changeid having sum(u.net) <> 0) -- any change who has only side in the user selection
          or u1.changeid in (select changeid from userselections u where payinggain <> 0 or payingloss <> 0 or a1pgain <> 0 or a1ploss <> 0 or stoppedgain<>0 or stoppedloss<>0 or waivergain <> 0 or waiverloss <> 0) -- both sides (if in user selection) if one side is an interesting status and there was a status change
           #{"or u1.#{header1}delta <> 0 -- unless the changes that cancel out but are transfers between grouped items" }
       )
       */
      , trans as
      (
        select
          case when coalesce(#{trans_header1}::varchar(200),'') = '' then 'unassigned' else #{trans_header1}::varchar(200) end row_header1
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
        t.creationdate >= #{db.sql_date(@start_date)}
        and t.creationdate < #{db.sql_date(end_date)}
      group by
        case when coalesce(#{trans_header1}::varchar(200),'') = '' then 'unassigned' else #{trans_header1}::varchar(200) end
      )
      , counts as
      (
        -- sum changes, if status doesnt change, then the change is a transfer
        select
          case when coalesce(#{header1}::varchar(200),'') = '' then 'unassigned' else #{header1}::varchar(200) end row_header1
          --, date_trunc('week', changedate)::date row_header2
          , sum(case when changedate < #{db.sql_date(@start_date)} then net else 0 end) as start_count
          , sum(case when changedate < #{db.sql_date(@start_date)} then a1pnet else 0 end) as a1p_start_count -- cant use a1pgain + a1ploss because they only count when a status changes, where as we want every a1p value in the selection, even if it is a transfer
          , sum(case when changedate < #{db.sql_date(@start_date)} then payingnet else 0 end) as paying_start_count
          , sum(case when changedate < #{db.sql_date(@start_date)} then stoppednet else 0 end) as stopped_start_count
          , sum(case when changedate < #{db.sql_date(@start_date)} then exitingnet else 0 end) as exiting_start_count
          , sum(case when changedate < #{db.sql_date(@start_date)} then waivernet else 0 end) as waiver_start_count
          , sum(case when changedate < #{db.sql_date(@start_date)} then othernet else 0 end) as other_start_count
          , sum(case when changedate < #{db.sql_date(@start_date)} then membernet else 0 end) as member_start_count
          , sum(case when changedate < #{db.sql_date(@start_date)} then greennet else 0 end) as green_start_count
          , sum(case when changedate < #{db.sql_date(@start_date)} then orangenet else 0 end) as orange_start_count

          /* SHARED BETWEEEN SUMMARY AND RUNNING SUMMARY - TODO REFACTOR */
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then a1pgain else 0 end) a1p_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then a1ploss else 0 end) a1p_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then payinggain else 0 end) paying_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then payingloss else 0 end) paying_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then stoppedgain else 0 end) stopped_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then stoppedloss else 0 end) stopped_loss
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then exitinggain else 0 end) exiting_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then exitingloss else 0 end) exiting_loss
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
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and status = ANY (#{exiting_db}) then othergain else 0 end) exiting_other_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and status = ANY (#{exiting_db}) then otherloss else 0 end) exiting_other_loss
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
          , sum(exitingnet) as exiting_end_count
          , sum(waivernet) as waiver_end_count
          , sum(othernet) as other_end_count
          , sum(membernet) as member_end_count
          , sum(greennet) as green_end_count
          , sum(orangenet) as orange_end_count
          , sum(net) as end_count

          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then a1pgain+a1ploss else 0 end) a1p_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then payinggain+payingloss else 0 end) paying_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then stoppedgain+stoppedloss else 0 end) stopped_net
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} then exitinggain+exitingloss else 0 end) exiting_net
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
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and coalesce(_status,'') = ANY (#{paying_db}) then exitingloss else 0 end) exiting_to_paying
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and not coalesce(_status,'') = ANY (#{paying_db}) then exitingloss else 0 end) exiting_to_other
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and _categorychangeid is null then exitinggain else 0 end) exiting_unchanged_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and (status = ANY (#{paying_db}) OR status = ANY (#{a1p_db})) and not internalTransfer then othergain else 0 end) external_gain
          , sum(case when changedate >= #{db.sql_date(@start_date)} and changedate < #{db.sql_date(end_date)} and (status = ANY (#{paying_db}) OR status = ANY (#{a1p_db})) and not internalTransfer then otherloss else 0 end) external_loss
        /* EO SHARED BETWEEEN SUMMARY AND RUNNING SUMMARY - TODO REFACTOR */

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
        left join trans t on t.row_header1 = c.row_header1

        union all

        select
          t.row_header1
          , 0::int start_count
          , 0::int a1p_start_count
          , 0::int paying_start_count
          , 0::int stopped_start_count
          , 0::int exiting_start_count
          , 0::int waiver_start_count
          , 0::int other_start_count
          , 0::int member_start_count
          , 0::int green_start_count
          , 0::int orange_start_count

          , 0 a1p_gain
          , 0 a1p_loss
          , 0 paying_gain
          , 0 paying_loss
          , 0 stopped_gain
          , 0 stopped_loss
          , 0 exiting_gain
          , 0 exiting_loss
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
          , 0 exiting_other_gain
          , 0 exiting_other_loss
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
          , 0 exiting_end_count
          , 0 waiver_end_count
          , 0 other_end_count
          , 0 member_end_count
          , 0 green_end_count
          , 0 orange_end_count
          , 0 end_count

          , 0 a1p_net
          , 0 paying_net
          , 0 stopped_net
          , 0 exiting_net
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
          , 0 exiting_to_paying
          , 0 exiting_to_other
          , 0 exiting_unchanged_gain
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
        or c.exiting_gain <> 0
        or c.exiting_loss <> 0
        or c.waiver_gain <> 0
        or c.waiver_loss <> 0
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
        , c.row_header1::varchar(200) row_header1_id
        --, ''::varchar(20) row_header2_id
        , c.start_count::int

        , c.a1p_start_count::int
        , c.a1p_gain::int as a1p_real_gain
        , c.a1p_unchanged_gain::int
        , c.a1p_newjoin::int
        , c.a1p_rejoin::int
        , c.a1p_loss::int as a1p_real_loss
        , c.a1p_net::int as a1p_real_net
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
        , c.stopped_loss::int as stopped_real_loss
        , c.stopped_net::int as stopped_real_net
        , c.stopped_to_paying::int
        , c.stopped_to_other::int
        , c.stopped_other_gain::int
        , c.stopped_other_loss::int
        , c.stopped_end_count::int
        
        -- Awaiting exit
        , c.exiting_start_count::int
        , c.exiting_gain::int as exiting_real_gain
        , c.exiting_unchanged_gain::int
        , c.exiting_loss::int as exiting_real_loss
        , c.exiting_net::int as exiting_real_net
        , c.exiting_to_paying::int
        , c.exiting_to_other::int
        , c.exiting_other_gain::int
        , c.exiting_other_loss::int
        , c.exiting_end_count::int

        , c.waiver_start_count::int
        , c.waiver_gain::int as waiver_real_gain
        , c.waiver_loss::int as waiver_real_loss
        , c.waiver_gain_good::int as waiver_real_gain_good
        , c.waiver_gain_bad::int as waiver_real_gain_bad
        , c.waiver_loss_good::int as waiver_real_loss_good
        , c.waiver_loss_bad::int as waiver_real_loss_bad
        , c.waiver_net::int
        , c.waiver_other_gain::int
        , c.waiver_other_loss::int
        , c.waiver_end_count::int

        , c.member_start_count::int
        , c.member_gain::int as member_real_gain
        , c.member_loss::int as member_real_loss
        , c.member_net::int as member_real_net
        , c.member_other_gain::int
        , c.member_other_loss::int
        , c.member_end_count::int

        , c.green_start_count::int
        , c.green_gain::int as green_real_gain
        , c.green_gain_nonmember::int as green_real_gain_nonmember
        , c.green_gain_member::int as green_real_gain_member
        , c.green_loss::int as green_real_loss
        , c.green_loss_nonmember::int as green_real_loss_nonmember
        , c.green_loss_member::int as green_real_loss_member
        , c.green_net::int as green_real_net
        , c.green_other_gain::int
        , c.green_other_loss::int
        , c.green_end_count::int

        , c.orange_start_count::int
        , c.orange_gain::int as orange_real_gain
        , c.orange_gain_nonmember::int as orange_real_gain_nonmember
        , c.orange_gain_member::int as orange_real_gain_member
        , c.orange_loss::int as orange_real_loss
        , c.orange_loss_nonmember::int as orange_real_loss_nonmember
        , c.orange_loss_member::int as orange_real_loss_member
        , c.orange_net::int as orange_real_net
        , c.orange_other_gain::int
        , c.orange_other_loss::int
        , c.orange_end_count::int

    -- dbeswick: other_other_gain/loss is returned as other_gain/loss in the SQL function.
        , c.other_start_count::int
        , c.other_gain::int other_real_gain
        , c.other_loss::int other_real_loss
        , c.other_net::int
        , c.other_other_gain::int other_gain
        , c.other_other_loss::int other_loss
        , c.other_end_count::int

        , c.external_gain::int
        , c.external_loss::int
        , c.net::int
        , c.end_count::int
        , ( case when 0 <> c.member_start_count + c.member_gain + c.member_loss + c.member_other_gain + c.member_other_loss - c.member_end_count then 'member' else '' end)
          || ( case when 0 <> 
            c.start_count + c.a1p_gain + c.a1p_loss + c.a1p_other_gain + c.a1p_other_loss 
            + c.paying_gain + c.paying_loss + c.paying_other_gain + c.paying_other_loss 
            + c.stopped_gain + c.stopped_loss + c.stopped_other_gain + c.stopped_other_loss 
            + c.exiting_gain + c.exiting_loss + c.exiting_other_gain + c.exiting_other_loss 
            + c.waiver_gain + c.waiver_loss + c.waiver_other_gain + c.waiver_other_loss 
            + c.other_other_gain + c.other_other_loss - c.end_count then ' total' else '' end)
          || ( case when 0 <> c.a1p_start_count + c.a1p_gain + c.a1p_loss + c.a1p_other_gain + c.a1p_other_loss - c.a1p_end_count then ' a1p' else '' end)
          || ( case when 0 <> c.paying_start_count + c.paying_gain + c.paying_loss + c.paying_other_gain + c.paying_other_loss - c.paying_end_count then ' paying' else '' end)
          || ( case when 0 <> c.stopped_start_count + c.stopped_gain + c.stopped_loss + c.stopped_other_gain + c.stopped_other_loss - c.stopped_end_count then ' stopped' else '' end)
          || ( case when 0 <> c.exiting_start_count + c.exiting_gain + c.exiting_loss + c.exiting_other_gain + c.exiting_other_loss - c.exiting_end_count then ' exiting' else '' end)
          || ( case when 0 <> c.waiver_start_count + c.waiver_gain + c.waiver_loss + c.waiver_other_gain + c.waiver_other_loss - c.waiver_end_count then ' waiver' else '' end)
          || ( case when 0 <> c.orange_start_count + c.orange_gain + c.orange_loss + c.orange_other_gain + c.orange_other_loss - c.orange_end_count then ' orange' else '' end)
          || ( case when 0 <> c.green_start_count + c.green_gain + c.green_loss + c.green_other_gain + c.green_other_loss - c.green_end_count then ' green' else '' end)
          || ( case when 0 <> c.a1p_start_count + c.paying_start_count + c.stopped_start_count + c.exiting_start_count + c.waiver_start_count - c.member_start_count then ' start count' else '' end)
          || ( case when 0 <> c.a1p_end_count + c.paying_end_count + c.stopped_end_count + c.exiting_end_count + c.waiver_end_count - c.member_end_count then ' end count' else '' end)
          || ( case when 0 <> c.green_start_count + c.orange_start_count - c.member_start_count then ' contributor start count' else '' end)
          || ( case when 0 <> c.green_end_count + c.orange_end_count - c.member_end_count then ' contributor end count' else '' end)
          as cross_check
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
