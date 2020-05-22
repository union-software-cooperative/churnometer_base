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

require './lib/query/query_detail_base'

# The detail query is used when 'drilling down' into non-groupby cells in the table display, accessed
# from the main interface's summary tab.
class QueryDetail < QueryDetailBase
  def initialize(app, churn_db, groupby_dimension, start_date, end_date, with_trans, site_constraint, filter_column, filter_param_hash)
    super(app, churn_db, groupby_dimension, filter_column, filter_param_hash)
    @start_date = start_date
    @end_date = end_date
    @with_trans = with_trans
    @site_constraint = site_constraint
  end

  # True if filtering by the given filter column must always require transactions to be disabled.
  def non_transaction_filter_column?(filter_column_name)
    ['contributors',
     'transactions',
     'income_net',
     'posted',
     'unposted'].include?(filter_column_name.downcase) == false
  end

  # See base class documentation.
  def self.filter_column_to_where_clause
    @filter_column_to_where_clause ||= {
      '' => '', # empty filter column
      'a1p_real_gain' => 'where c.a1p_real_gain<>0',
      'a1p_unchanged_gain' => 'where c.a1p_unchanged_gain<>0',
      'a1p_newjoin' => 'where c.a1p_newjoin<>0',
      'a1p_rejoin' => 'where c.a1p_rejoin<>0',
      'a1p_real_loss' => 'where c.a1p_real_loss<>0',
      'a1p_real_net' => 'where c.a1p_real_net<>0',
      'a1p_to_paying' => 'where c.a1p_to_paying<>0',
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
      'stopped_real_loss' => 'where c.stopped_real_loss<>0',
      'stopped_real_net' => 'where c.stopped_real_net<>0',
      'stopped_to_paying' => 'where c.stopped_to_paying<>0',
      'stopped_to_other' => 'where c.stopped_to_other<>0',
      'stopped_other_gain' => 'where c.stopped_other_gain<>0',
      'stopped_other_loss' => 'where c.stopped_other_loss<>0',
      'waiver_real_gain' => 'where c.waiver_real_gain<>0',
      'waiver_real_loss' => 'where c.waiver_real_loss<>0',
      'waiver_real_gain_good' => 'where c.waiver_real_gain_good<>0',
      'waiver_real_gain_bad' => 'where c.waiver_real_gain_bad<>0',
      'waiver_real_loss_good' => 'where c.waiver_real_loss_good<>0',
      'waiver_real_loss_bad' => 'where c.waiver_real_loss_bad<>0',
      'waiver_real_net' => 'where c.waiver_real_net<>0',
      'waiver_other_gain' => 'where c.waiver_other_gain<>0',
      'waiver_other_loss' => 'where c.waiver_other_loss<>0',
      'other_gain' => 'where c.other_other_gain<>0',
      'other_loss' => 'where c.other_other_loss<>0',

      'member_real_gain' => 'where c.member_real_gain<>0',
      'member_real_loss' => 'where c.member_real_loss<>0',
      'member_real_net' => 'where c.member_real_net<>0',
      'member_other_loss' => 'where c.member_other_loss<>0',
      'member_other_gain' => 'where c.member_other_gain<>0',

      'green_real_gain' => 'where c.green_real_gain<>0',
      'green_real_gain_nonmember' => 'where c.green_real_gain_nonmember<>0',
      'green_real_loss_nonmember' => 'where c.green_real_loss_nonmember<>0',
      'green_real_gain_member' => 'where c.green_real_gain_member<>0',
      'green_real_loss_member' => 'where c.green_real_loss_member<>0',
      'green_real_loss' => 'where c.green_real_loss<>0',
      'green_real_net' => 'where c.green_real_net<>0',
      'green_other_gain' => 'where c.green_other_gain<>0',
      'green_other_loss' => 'where c.green_other_loss<>0',

      'orange_real_gain' => 'where c.orange_real_gain<>0',
      'orange_real_gain_nonmember' => 'where c.orange_real_gain_nonmember<>0',
      'orange_real_loss_nonmember' => 'where c.orange_real_loss_nonmember<>0',
      'orange_real_gain_member' => 'where c.orange_real_gain_member<>0',
      'orange_real_loss_member' => 'where c.orange_real_loss_member<>0',
      'orange_real_loss' => 'where c.orange_real_loss<>0',
      'orange_real_net' => 'where c.orange_real_net<>0',
      'orange_other_gain' => 'where c.orange_other_gain<>0',
      'orange_other_loss' => 'where c.orange_other_loss<>0',

      'contributors' => 'where (c.posted<>0 or c.unposted<>0)',
      'income_net' => 'where (c.posted<>0 or c.unposted<>0)',
      'posted' => 'where c.posted<>0',
      'unposted' => 'where c.unposted<>0',
      'transactions' => 'where (c.posted<>0 or c.unposted<>0)',
    }
  end

  def query_string
    db = @churn_db.db

    header1 = @groupby_dimension.column_base_name

    filter = modified_filter_for_site_constraint(filter_terms(), @site_constraint, @start_date, @end_date)

    non_status_filter = filter.exclude('status')
    user_selections_filter = filter.include('status')

    #with_trans = @with_trans && non_transaction_filter_column?(@filter_column) == false
    with_trans = @with_trans

    end_date = @end_date + 1

    # paying_db = db.quote(@app.member_paying_status_code)
    # a1p_db = db.quote(@app.member_awaiting_first_payment_status_code)
    # stoppedpay_db = db.quote(@app.member_stopped_paying_status_code)
    paying_db = db.sql_array(@app.paying_statuses)
    a1p_db = db.sql_array(@app.a1p_statuses)
    stoppedpay_db = db.sql_array(@app.stopped_statuses)

    sql = <<-EOS
      -- detail query
      with nonstatusselections as
      (
        -- finds all changes matching user criteria
        select
          *
        from
          #{@source}
        where
          changedate < #{db.sql_date(end_date)} -- we need to count every value since Churnobyls start to determine start_count.  But everything after enddate can be ignored.
          #{sql_for_filter_terms(non_status_filter, true)}
      )
      , userselections as
      (
        select
          *
        from
          nonstatusselections
        where
          changedate >= #{db.sql_date(@start_date)} -- we are not calculating start_counts, so we dont need anything before this date
          #{sql_for_filter_terms(user_selections_filter, true)}
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
          , case when #{header1 == 'userid' ? '' : "u1.#{header1}delta <> 0" } then 1 else 0 end  group_transfer
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
        t.creationdate >= #{db.sql_date(@start_date)}
        and t.creationdate < #{db.sql_date(end_date)}
      group by
        case when coalesce(u1.#{db.quote_db(header1)}::varchar(200),'') = '' then 'unassigned' else u1.#{db.quote_db(header1)}::varchar(200) end
        , t.changeid
        , t.memberid
    )
      , counts as
      (
        -- sum changes, if status doesnt change, then the change is a transfer
        select
          c.memberid
          , c.changeid::bigint
          , case when coalesce(#{db.quote_db(header1)}::varchar(50),'') = '' then 'unassigned' else #{db.quote_db(header1)}::varchar(50) end row_header

          , a1pgain::bigint a1p_real_gain
          , a1ploss::bigint a1p_real_loss
            , payinggain::bigint paying_real_gain
          , payingloss::bigint paying_real_loss
          , stoppedgain::bigint stopped_real_gain
            , stoppedloss::bigint stopped_real_loss

          , waivergain::bigint waiver_real_gain
            , waiverloss::bigint waiver_real_loss
            , waivergaingood::bigint waiver_real_gain_good
            , waivergainbad::bigint waiver_real_gain_bad
            , waiverlossgood::bigint waiver_real_loss_good
            , waiverlossbad::bigint waiver_real_loss_bad
            , membergain::bigint member_real_gain
            , memberloss::bigint member_real_loss

            , greengain::bigint green_real_gain
            , greenloss::bigint green_real_loss
            , greengain_nonmember::bigint green_real_gain_nonmember
            , greenloss_nonmember::bigint green_real_loss_nonmember
            , greengain_member::bigint green_real_gain_member
            , greenloss_member::bigint green_real_loss_member

            , orangegain::bigint orange_real_gain
            , orangeloss::bigint orange_real_loss
            , orangegain_nonmember::bigint orange_real_gain_nonmember
            , orangeloss_nonmember::bigint orange_real_loss_nonmember
            , orangegain_member::bigint orange_real_gain_member
            , orangeloss_member::bigint orange_real_loss_member

          , case when coalesce(status, '') = ANY (#{a1p_db}) then othergain else 0 end::bigint a1p_other_gain
          , case when coalesce(status, '') = ANY (#{a1p_db}) then otherloss else 0 end::bigint a1p_other_loss
            , case when coalesce(status, '') = ANY (#{paying_db}) then othergain else 0 end::bigint paying_other_gain
          , case when coalesce(status, '') = ANY (#{paying_db}) then otherloss else 0 end::bigint paying_other_loss
          , case when coalesce(status, '') = ANY (#{stoppedpay_db}) then othergain else 0 end::bigint stopped_other_gain
          , case when coalesce(status, '') = ANY (#{stoppedpay_db}) then otherloss else 0 end::bigint stopped_other_loss
          , case when waivernet <> 0 then othergain else 0 end waiver_other_gain
            , case when waivernet <> 0 then otherloss else 0 end waiver_other_loss
            , case when not (status = ANY (#{paying_db}) or status = ANY (#{a1p_db}) or status = ANY (#{stoppedpay_db}) or waivernet <> 0) then othergain else 0 end::bigint other_other_gain
            , case when not (status = ANY (#{paying_db}) or status = ANY (#{a1p_db}) or status = ANY (#{stoppedpay_db}) or waivernet <> 0) then otherloss else 0 end::bigint other_other_loss
            , case when (set_transfer = 1 or group_transfer = 1) then othergain else 0 end member_other_gain
            , case when (set_transfer = 1 or group_transfer = 1) then otherloss else 0 end member_other_loss
            , case when (set_transfer = 1 or group_transfer = 1) then othergreengain else 0 end green_other_gain
              , case when (set_transfer = 1 or group_transfer = 1) then othergreenloss else 0 end green_other_loss
            , case when (set_transfer = 1 or group_transfer = 1) then otherorangegain else 0 end orange_other_gain
              , case when (set_transfer = 1 or group_transfer = 1) then otherorangeloss else 0 end orange_other_loss


          , (a1pgain+a1ploss)::bigint a1p_real_net
            , (payinggain+payingloss)::bigint paying_real_net
          , (stoppedgain+stoppedloss)::bigint stopped_real_net
          , (waivergain + waiverloss)::bigint waiver_real_net
          , (othergain+otherloss)::bigint other_real_net
          , (membergain + memberloss)::bigint member_real_net
          , (greengain + greenloss)::bigint green_real_net
          , (orangegain + orangeloss)::bigint orange_real_net
          , net::bigint

          -- odd columns
          --, case when _changeid is null then a1pgain else 0 end::bigint a1p_unchanged_gain
          , CASE WHEN _categorychangeid IS NULL THEN a1pgain ELSE 0 END::bigint a1p_unchanged_gain
          , case when coalesce(_status, '') = '' then a1pgain else 0 end::bigint a1p_newjoin
          , case when coalesce(_status, '') <> '' then a1pgain else 0 end::bigint a1p_rejoin
          , case when coalesce(_status, '') = ANY (#{paying_db}) then a1ploss else 0 end::bigint a1p_to_paying
          , case when not coalesce(_status, '') = ANY (#{paying_db}) then a1ploss else 0 end::bigint a1p_to_other
          --, case when _changeid is null then stoppedgain else 0 end::bigint stopped_unchanged_gain
          , CASE WHEN _categorychangeid IS NULL THEN stoppedgain ELSE 0 END::bigint stopped_unchanged_gain
          , case when coalesce(_status, '') = ANY (#{paying_db}) then stoppedloss else 0 end::bigint stopped_to_paying
          , case when not coalesce(_status, '') = ANY (#{paying_db}) then stoppedloss else 0 end::bigint stopped_to_other
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
            or c.stoppedgain <> 0
            or c.stoppedloss <> 0
            or c.waivergain <> 0
            or c.waiverloss <> 0
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
        , c.a1p_real_net
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
        , c.stopped_real_loss
        , c.stopped_real_net
        , c.stopped_to_paying
        , c.stopped_to_other
        , c.stopped_other_loss
        , c.stopped_other_gain
        , c.other_other_gain
        , c.other_other_loss
        , c.waiver_real_gain
        , c.waiver_real_loss
        , c.waiver_real_gain_good
        , c.waiver_real_gain_bad
        , c.waiver_real_loss_good
        , c.waiver_real_loss_bad
        , c.waiver_real_net
        , c.waiver_other_gain
        , c.waiver_other_loss
        , c.member_real_gain
        , c.member_real_loss
        , c.member_real_net
        , c.member_other_gain
        , c.member_other_loss

        , c.green_real_gain
        , c.green_real_gain_nonmember
        , c.green_real_loss_nonmember
        , c.green_real_gain_member
        , c.green_real_loss_member
        , c.green_real_loss
        , c.green_real_net
        , c.green_other_gain
        , c.green_other_loss

        , c.orange_real_gain
        , c.orange_real_gain_nonmember
        , c.orange_real_loss_nonmember
        , c.orange_real_gain_member
        , c.orange_real_loss_member
        , c.orange_real_loss
        , c.orange_real_net
        , c.orange_other_gain
        , c.orange_other_loss


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
        , 0::bigint a1p_real_net
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
        , 0::bigint stopped_real_loss
        , 0::bigint stopped_real_net
        , 0::bigint stopped_to_paying
        , 0::bigint stopped_to_other
        , 0::bigint stopped_other_loss
        , 0::bigint stopped_other_gain
        , 0::bigint waiver_real_gain
        , 0::bigint waiver_real_loss
        , 0::bigint waiver_real_gain_good
        , 0::bigint waiver_real_gain_bad
        , 0::bigint waiver_real_loss_good
        , 0::bigint waiver_real_loss_bad
        , 0::bigint waiver_real_net
        , 0::bigint waiver_other_gain
        , 0::bigint waiver_other_loss
        , 0::bigint other_other_gain
        , 0::bigint other_other_loss
        , 0::bigint member_real_gain
        , 0::bigint member_real_loss
        , 0::bigint member_real_net
        , 0::bigint member_other_gain
        , 0::bigint member_other_loss

        , 0::bigint green_real_gain
        , 0::bigint green_real_loss
        , 0::bigint green_real_gain_nonmember
        , 0::bigint green_real_loss_nonmember
        , 0::bigint green_real_gain_member
        , 0::bigint green_real_loss_member
        , 0::bigint green_real_net
        , 0::bigint green_other_gain
        , 0::bigint green_other_loss

        , 0::bigint orange_real_gain
        , 0::bigint orange_real_loss
        , 0::bigint orange_real_gain_nonmember
        , 0::bigint orange_real_loss_nonmember
        , 0::bigint orange_real_gain_member
        , 0::bigint orange_real_loss_member
        , 0::bigint orange_real_net
        , 0::bigint orange_other_gain
        , 0::bigint orange_other_loss

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
        , c.a1p_real_net
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
        , c.stopped_real_loss
        , c.stopped_real_net
        , c.stopped_to_paying
        , c.stopped_to_other
        , c.stopped_other_loss
        , c.stopped_other_gain
        , c.waiver_real_gain
        , c.waiver_real_loss
        , c.waiver_real_gain_good
        , c.waiver_real_gain_bad
        , c.waiver_real_loss_good
        , c.waiver_real_loss_bad
        , c.waiver_real_net
        , c.waiver_other_gain
        , c.waiver_other_loss
        , c.other_other_gain other_gain
        , c.other_other_loss other_loss
        , c.member_real_gain
        , c.member_real_loss
        , c.member_real_net
        , c.member_other_gain
        , c.member_other_loss

        , c.green_real_gain
        , c.green_real_loss
        , c.green_real_gain_nonmember
        , c.green_real_loss_nonmember
        , c.green_real_gain_member
        , c.green_real_loss_member
        , c.green_real_net
        , c.green_other_gain
        , c.green_other_loss

        , c.orange_real_gain
        , c.orange_real_loss
        , c.orange_real_gain_nonmember
        , c.orange_real_loss_nonmember
        , c.orange_real_gain_member
        , c.orange_real_loss_member
        , c.orange_real_net
        , c.orange_other_gain
        , c.orange_other_loss

        , c.posted
        , c.unposted
      from
        withtrans c
        left join displaytext d1 on d1.attribute = #{db.quote(header1)} and d1.id = c.row_header
    EOS

    sql << where_clause_for_filter_column(@filter_column)

    sql << <<-EOS
      order by
        c.row_header asc
    EOS

    sql
  end
end
