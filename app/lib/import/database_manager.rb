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

require './lib/churn_db'
require 'open3.rb'

class DatabaseManager
  def db
    @db
  end

  def initialize(app)
    @dimensions = app.custom_dimensions
    @db = Db.new(app)
    @app = app

    member_statuses = @app.all_member_statuses
    nonwaiver_statuses = member_statuses - @app.waiver_statuses

    paying_statuses = @app.paying_statuses
    a1p_statuses = @app.a1p_statuses
    stopped_statuses = @app.stopped_statuses

    green_statuses = @app.green_member_statuses
    orange_statuses = member_statuses - green_statuses

    # @paying_db = @db.quote(@app.member_paying_status_code)
    # @a1p_db = @db.quote(@app.member_awaiting_first_payment_status_code)
    # @stopped_db = @db.quote(@app.member_stopped_paying_status_code)
    @paying_db = @db.sql_array(@app.paying_statuses, 'varchar')
    @a1p_db = @db.sql_array(@app.a1p_statuses, 'varchar')
    @stopped_db = @db.sql_array(@app.stopped_statuses, 'varchar')
    @waiver_db = @db.sql_array(@app.waiver_statuses, 'varchar') # "'pat', 'anbs', 'assoc', 'fhardship', 'trainee', 'fam', 'half pay', 'leave', 'life', 'lsl', 'mat', 'o/s', 'pend', 'res', 'stu', 'study', 'waiv', 'work', 'unemployed', 'emp unkn', 'mid career', 'nofee'"
    @member_db = @db.sql_array(member_statuses, 'varchar')
    @nonwaiver_db = @db.sql_array(nonwaiver_statuses, 'varchar')
    @green_db = @db.sql_array(green_statuses, 'varchar')
    @orange_db = @db.sql_array(orange_statuses, 'varchar')
  end

  def close_db()
    @db.close_db()
  end

  def dimensions
    @dimensions.reject { |d| d.column_base_name == 'userid' }
  end

  def app
    @app
  end

  def migrate_rebuild_without_indexes_sql()
    sql = <<-SQL
      drop table if exists importing cascade;
      select 0 as importing into importing;

      drop function if exists insertmemberfact() cascade;
      drop function if exists updatememberfacthelper() cascade;

      drop view if exists memberchangefromlastchange cascade;
      drop view if exists memberchangefrommembersourceprev cascade;
      drop view if exists lastchange cascade;
      drop view if exists memberfacthelperquery cascade;

      drop table if exists memberfact_migration cascade ;
      drop table if exists membersourceprev_migration cascade;
      drop table if exists memberfacthelper_migration cascade;

      alter table memberfact rename to memberfact_migration;
      alter sequence memberfact_changeid_seq rename to memberfact_migration_changeid_seq;
      alter table membersourceprev rename to membersourceprev_migration;
      alter table #{@app.memberfacthelper_table} rename to memberfacthelper_migration;

      #{rebuild_membersource_sql};
      #{rebuild_membersourceprev_sql};
      #{memberfact_sql};

      #{lastchange_sql};
      #{memberchangefromlastchange_sql};
      #{memberchangefrommembersourceprev_sql};
      #{memberfacthelperquery_sql};
      #{memberfacthelper_sql}

      #{updatememberfacthelper_sql};
      #{insertmemberfact_sql};
    SQL
  end

  def rebuild_from_scratch_without_indexes_sql()
    sql = <<-SQL
      drop table if exists importing;
      select 0 as importing into importing;
      create table if not exists appstate (key varchar, value varchar);

      drop function if exists inserttransactionfact() cascade;
      drop function if exists updatedisplaytext() cascade;
      drop function if exists insertmemberfact() cascade ;
      drop function if exists updatememberfacthelper() cascade;

      drop view if exists memberchangefromlastchange cascade;
      drop view if exists memberchangefrommembersourceprev cascade;
      drop view if exists lastchange cascade;
      drop view if exists memberfacthelperquery cascade;

      drop table if exists memberfact_migration cascade;
      drop table if exists membersourceprev_migration cascade;
      drop table if exists memberfacthelper_migration cascade;

      drop table if exists transactionfact_migration cascade;
      drop table if exists transactionsourceprev_migration cascade;
      drop table if exists displaytext_migration cascade;

      alter table transactionfact rename to transactionfact_migration;
      alter table transactionsourceprev rename to transactionsourceprev_migration;
      alter table displaytext rename to displaytext_migration;

      alter table memberfact rename to memberfact_migration;
      alter table membersourceprev rename to membersourceprev_migration;
      alter table #{@app.memberfacthelper_table} rename to memberfacthelper_migration;

      #{memberfact_sql};
      #{rebuild_membersourceprev_sql};
      #{rebuild_membersource_sql};

      #{displaytext_sql};
      #{rebuild_transactionsourceprev_sql};
      #{transactionfact_sql};

      #{rebuild_displaytextsource_sql};
      #{rebuild_transactionsource_sql};

      #{lastchange_sql};
      #{memberchangefromlastchange_sql};
      #{memberchangefrommembersourceprev_sql};
      #{memberfacthelperquery_sql};
      #{memberfacthelper_sql}

      #{updatememberfacthelper_sql};
      #{insertmemberfact_sql};
      #{updatedisplaytext_sql};
      #{inserttransactionfact_sql};
    SQL
  end

  def rebuild_sql
    <<-SQL
      #{rebuild_from_scratch_without_indexes_sql}
      #{rebuild_most_indexes_sql}
      #{rebuild_memberfacthelper_indexes_sql}

      VACUUM memberfact;
      VACUUM memberfacthelper;
      VACUUM transactionfact;
      VACUUM displaytext;
      VACUUM membersource;
      VACUUM membersourceprev;
      VACUUM transactionsource;
      VACUUM transactionsourceprev;
      VACUUM displaytextsource;

      ANALYSE memberfact;
      ANALYSE memberfact;
      ANALYSE memberfacthelper;
      ANALYSE transactionfact;
      ANALYSE displaytext;
      ANALYSE membersource;
      ANALYSE membersourceprev;
      ANALYSE transactionsource;
      ANALYSE transactionsourceprev;
      ANALYSE displaytextsource;
    SQL
  end

  def rebuild_memberfacthelper_sql_ary()
    ["drop view if exists memberfacthelperquery cascade;",
     memberfacthelperquery_sql(),
     memberfacthelper_sql(),
     updatememberfacthelper_sql()] + rebuild_memberfacthelper_indexes_sql().split($/)
  end

  def rebuild_memberfacthelper_sql()
    rebuild_memberfacthelper_sql_ary.join($/)
  end

  def rebuild()
    db.ex(rebuild_from_scratch_without_indexes_sql)
    db.ex(rebuild_most_indexes_sql)
    db.ex(rebuild_memberfacthelper_indexes_sql)

    # ANALYSE and VACUUM have to be run as separate database calls
    str = <<-SQL
      VACUUM memberfact;
      VACUUM memberfacthelper;
      VACUUM transactionfact;
      VACUUM displaytext;
      VACUUM membersource;
      VACUUM membersourceprev;
      VACUUM transactionsource;
      VACUUM transactionsourceprev;
      VACUUM displaytextsource;

      ANALYSE memberfact;
      ANALYSE memberfact;
      ANALYSE memberfacthelper;
      ANALYSE transactionfact;
      ANALYSE displaytext;
      ANALYSE membersource;
      ANALYSE membersourceprev;
      ANALYSE transactionsource;
      ANALYSE transactionsourceprev;
      ANALYSE displaytextsource;
    SQL

    str.split("\n").each { |cmd| db.ex(cmd) }
  end

  def rebuild_displaytextsource_sql
    sql = <<-SQL
      drop table if exists displaytextsource cascade;

      create table displaytextsource
      (
        attribute varchar(255) not null
        , id varchar(255) null
        , displaytext varchar(255) null
      );

    SQL
  end

  def rebuild_displaytextsource
    db.ex(rebuild_displaytextsource_sql)
  end

  def displaytext_sql
    sql = <<-SQL
      create table displaytext
      (
        attribute varchar(255) not null
        , id varchar(255) null
        , displaytext varchar(255) null
      );

    SQL
  end

  def displaytext
    db.ex(displaytext_sql)
  end

  def membersource_sql
    sql = <<-SQL
      create table membersource
      (
        memberid varchar(255) not null
        , userid varchar(255) null
        , status varchar(255) not null
        -- this could also work? -kbuckley, 2017-03-15
        , #{dimensions.map(&:column_base_name).join(" varchar(255) null\n        , ")} varchar(255) null
      )
    SQL

    # dimensions.each { |d| sql << <<-REPEAT }
    #     , #{d.column_base_name} varchar(255) null
    # REPEAT
    #
    # sql << <<-SQL
    #   )
    #
    # SQL
  end

  def rebuild_membersource_sql
    sql = <<-SQL
      drop table if exists membersource cascade;
      #{membersource_sql};
    SQL
  end

  def empty_membersource
    db.ex("delete from membersource");
  end

  def rebuild_membersource
    db.ex(rebuild_membersource_sql)
  end

  def rebuild_membersourceprev_sql
    sql = rebuild_membersource_sql.gsub('membersource', 'membersourceprev')
  end

  def rebuild_membersourceprev
    db.ex(rebuild_membersourceprev_sql)
  end

  def memberfact_sql
    sql = <<-SQL
      create table memberfact
      (
        changeid BIGSERIAL PRIMARY KEY
        , changedate timestamp not null
        , memberid varchar(255) not null
        , userid varchar(255) null
        , oldstatus varchar(255) null
        , newstatus varchar(255) null
    SQL

    dimensions.each { | d | sql << <<-REPEAT }
      , old#{d.column_base_name} varchar(255) null
      , new#{d.column_base_name} varchar(255) null
    REPEAT

    sql << <<-SQL
      );
    SQL
  end

  def lastchange_sql
    sql = <<-SQL
      create view lastchange as
        select
          changeid
          , changedate
          , memberid
          , userid
          , newstatus status
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          , new#{d.column_base_name} as #{d.column_base_name}
    REPEAT

    sql << <<-SQL
        from
          memberfact
        where (
          memberfact.changeid IN (
            select
              max(memberfact.changeid) AS max
            from
              memberfact
            group by
              memberfact.memberid
          )
        );
    SQL
  end


  def fix_out_of_sequence_changes_sql
    sql = <<-SQL
      with laggy as (
        select changeid, lag(changeid) over (partition by memberid order by changedate) as lagid from memberfact
      )
      update
        memberfact
      set
        oldstatus = m2.newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        , old#{d.column_base_name} = m2.new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
      from
        laggy
        inner join memberfacttest m1 on laggy.changeid = m1.changeid
        inner join memberfacttest m2 on laggy.lagid = m2.changeid
      where
        memberfact.changeid = m1.changeid;

    SQL

    sql << <<-SQL
      select
        count(*)
      from
        memberfact
      where
        coalesce(oldstatus,'') = coalesce(newstatus,'')
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        and coalesce(old#{d.column_base_name},'') = coalesce(new#{d.column_base_name},'')
    REPEAT

    sql
  end


  def memberchangefromlastchange_sql

    sql = <<-SQL
      -- find changes, adds and deletions in latest data
      create or replace view memberchangefromlastchange as
      -- find members who've changed in latest data
      select
        now() as changedate
        , old.memberid
        , new.userid
        , trim(lower(old.status)) as oldstatus
        , trim(lower(new.status)) as newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        , trim(lower(old.#{d.column_base_name})) as old#{d.column_base_name}
        , trim(lower(new.#{d.column_base_name})) as new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
      from
        lastchange old
        inner join membersource new on old.memberid = new.memberid
      where
        trim(lower(coalesce(old.status, ''))) <> trim(lower(coalesce(new.status, '')))
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        OR trim(lower(coalesce(old.#{d.column_base_name}, ''))) <> trim(lower(coalesce(new.#{d.column_base_name}, '')))
    REPEAT

    sql << <<-SQL
      UNION ALL
      -- find members missing in latest data
      select
        now() as changedate
        , old.memberid
        , null -- We have a problem here - this doesn't indicate the user that deleted the member
        , trim(lower(old.status)) as oldstatus
        , null as newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        , trim(lower(old.#{d.column_base_name})) as old#{d.column_base_name}
        , null as new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
      from
        lastchange old
      where
        not old.memberid in (
          select
            memberid
          from
            membersource
        )
        AND not (
          -- if all values for the member's last change are null
          --, then the member has already been inserted as missing
          -- and doesn't need to be inserted again
          old.status IS NULL
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          AND old.#{d.column_base_name} IS NULL
    REPEAT

    sql << <<-SQL
        )
      UNION ALL
      -- find members appearing in latest data
      select
        now() as changedate
        , new.memberid
        , new.userid
        , null as oldstatus
        , trim(lower(new.status)) as newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        , null as old#{d.column_base_name}
        , trim(lower(new.#{d.column_base_name})) as new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
      from
        membersource new
      where
        not new.memberid in (
          select
            lastchange.memberid
          from
            lastchange
        )
    SQL
  end

  def memberchangefrommembersourceprev_sql
    memberchangefromlastchange_sql.gsub('lastchange', 'membersourceprev')
  end

  def insertmemberfact_sql

    sql = <<-SQL
      CREATE OR REPLACE FUNCTION insertmemberfact(import_date timestamp) RETURNS void
      AS $BODY$begin

        -- don't run the import if nothing is ready for comparison
        if 0 = (select count(*) from membersource) then
          return;
        end if;

        insert into memberfact (
          changedate
          , memberid
          , userid
          , oldstatus
          , newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          , old#{d.column_base_name}
          , new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
        )
        select
          import_date
          , memberid
          , userid
          , oldstatus
          , newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          , old#{d.column_base_name}
          , new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
        from
          memberchangefromlastchange;

        -- finalise import, so running this again won't do anything
        delete from memberSourcePrev;
        insert into memberSourcePrev select * from memberSource;
        delete from memberSource;

      end$BODY$
        LANGUAGE plpgsql
        COST 100
        CALLED ON NULL INPUT
        SECURITY INVOKER
        VOLATILE;
    SQL
  end

  def updatememberfacthelper_sql
    <<-SQL
    CREATE OR REPLACE FUNCTION updatememberfacthelper() RETURNS void
      AS $BODY$begin
        -- update memberfacthelper with new facts (helper is designed for fast aggregration)
        insert into memberfacthelper
        select
          *
        from
          memberfacthelperquery h
        where
          -- only insert facts we haven't already inserted
          changeid not in (select changeid from memberfacthelper)
          and       (
        -- only include people who've been an interesting status
        exists (
          select
            1
          from
            memberfact mf
          where
            mf.memberid = h.memberid
            and (
              oldstatus = ANY (#{@member_db})
              or newstatus = ANY (#{@member_db})
            )
        )
        -- or have paid something since tracking begun
        or exists (
          select
            1
          from
            transactionfact tf
          where
            tf.memberid = h.memberid
        )
      );

        -- as new status changes happen, next status changes need to be updated
        update
          memberfacthelper
        set
          duration = h.duration
          , _changeid = h._changeid
          , _changedate = h._changedate
          , nextchangeid = h.nextchangeid
          , nextchangedate = h.nextchangedate
          , changeduration = h.changeduration
        from
          memberfacthelperquery h
        where
          memberfacthelper.changeid = h.changeid
          and memberfacthelper.net = h.net
          and (
            coalesce(memberfacthelper.duration,0) <> coalesce(h.duration,0)
            or coalesce(memberfacthelper._changeid,0) <> coalesce(h._changeid,0)
            or coalesce(memberfacthelper._changedate, '1/1/1900') <> coalesce(h._changedate, '1/1/1900')
            or coalesce(memberfacthelper.changeduration,0) <> coalesce(h.changeduration,0)
            or coalesce(memberfacthelper.nextchangeid,0) <> coalesce(h.nextchangeid,0)
            or coalesce(memberfacthelper.nextchangedate, '1/1/1900') <> coalesce(h.nextchangedate, '1/1/1900')
          );

      end$BODY$
        LANGUAGE plpgsql
        COST 100
        CALLED ON NULL INPUT
        SECURITY INVOKER
        VOLATILE;
    SQL
  end


  def memberfacthelperquery_sql

    sql = <<-SQL
      create or replace view memberfacthelperquery as
      with mfnextstatuschange as
      (
        -- find the next status change for each statuschange
        select
          lead(changeid)  over (partition by memberid order by changeid) nextstatuschangeid
          , mf.*
        from
          memberfact mf
        where
          coalesce(mf.oldstatus,'') <> coalesce(mf.newstatus,'')
      )
      , nextstatuschange as (
        select
          c.changeid
          , n.changeid nextchangeid
          , n.changedate nextchangedate
          , n.newstatus nextstatus
          , (coalesce(n.changedate::date, current_date) - c.changedate::date)::int nextduration
        from
          mfnextstatuschange c
          left join memberfact n on c.nextstatuschangeid = n.changeid
      ), mfnextchange as
      (
        -- find the next status change for each statuschange
        select
          lead(changeid)  over (partition by memberid order by changeid) nextchangeid
          , mf.*
        from
          memberfact mf
      )
      , nextchange as (
        select
          c.changeid
          , n.changeid nextchangeid
          , coalesce(n.changedate::date, current_date) nextchangedate
          , n.newstatus nextstatus
          , (coalesce(n.changedate::date, current_date) - c.changedate::date)::int nextduration
        from
          mfnextchange c
          left join memberfact n on c.nextchangeid = n.changeid
      )
      select
        memberfact.changeid
        , changedate
        , memberid
        , userid
        , -1 as net
        , 0 as gain
        , 1 as loss
        , coalesce(oldstatus, '') as status
        , coalesce(newstatus, '') as _status
        , case when
            (
              (
                coalesce(oldstatus, '') = ANY (#{@nonwaiver_db})
                or coalesce(newstatus, '') = ANY (#{@nonwaiver_db})
              )
              -- This assumes only one status code for paying, one code for stopped and one code for a1p
              -- If there was more than one code for each of these we'd need a more verbose method for
              -- checking changes between these statii, like is used for waiver_db
              and coalesce(oldstatus, '') <> coalesce(newstatus, '') -- when changing between a1p, paying and stopped
            )
            or
            (
              (
                coalesce(oldstatus, '') = ANY (#{@waiver_db})
                and not coalesce(newstatus, '') = ANY (#{@waiver_db})
              )
              or
              (
                not coalesce(oldstatus, '') = ANY (#{@waiver_db})
                and coalesce(newstatus, '') = ANY (#{@waiver_db})
              )
            )
            then -1 else 0 end as statusdelta
        , 0 as a1pgain
        , case when coalesce(oldstatus, '') = ANY (#{@a1p_db}) and not coalesce(newstatus, '') = ANY (#{@a1p_db})
            then -1 else 0 end as a1ploss
        , case when coalesce(oldstatus, '') = ANY (#{@a1p_db})
          then -1 else 0 end as a1pnet
        , 0 as payinggain
        , case when coalesce(oldstatus, '') = ANY (#{@paying_db}) and not coalesce(newstatus, '') = ANY (#{@paying_db})
          then -1 else 0 end as payingloss
        , case when coalesce(oldstatus, '') = ANY (#{@paying_db})
          then -1 else 0 end as payingnet
        , 0 as stoppedgain
        , case when coalesce(oldstatus, '') = ANY (#{@stopped_db}) and not coalesce(newstatus, '') = ANY (#{@stopped_db})
            then -1 else 0 end as stoppedloss
        , case when coalesce(oldstatus, '') = ANY (#{@stopped_db})
          then -1 else 0 end as stoppednet

        , 0 as waivergain
        , 0 as waivergaingood
        , 0 as waivergainbad
        , case when coalesce(oldstatus, '') = ANY (#{@waiver_db}) and not coalesce(newstatus, '') = ANY (#{@waiver_db})
            then -1 else 0 end as waiverloss
        , case when coalesce(oldstatus, '') = ANY (#{@waiver_db}) and coalesce(newstatus, '') = ANY (#{@nonwaiver_db})
            then -1 else 0 end as waiverlossgood
        , case when coalesce(oldstatus, '') = ANY (#{@waiver_db}) and not coalesce(newstatus, '') = ANY (#{@member_db})
            then -1 else 0 end as waiverlossbad
        , case when coalesce(oldstatus, '') = ANY (#{@waiver_db})
          then -1 else 0 end as waivernet


        , 0 as othergain
        , case when
            NOT (coalesce(oldstatus, '') = ANY (#{@a1p_db}) and not coalesce(newstatus, '') = ANY (#{@a1p_db}))
            AND NOT (coalesce(oldstatus, '') = ANY (#{@paying_db}) and not coalesce(newstatus, '') = ANY (#{@paying_db}))
            AND NOT (coalesce(oldstatus, '') = ANY (#{@stopped_db}) and not coalesce(newstatus, '') = ANY (#{@stopped_db}))
            AND NOT (coalesce(oldstatus, '') = ANY (#{@waiver_db}) and not coalesce(newstatus, '') = ANY (#{@waiver_db}))
            then -1 else 0 end as otherloss
        , case when
            NOT (coalesce(oldstatus, '') = ANY (#{@a1p_db}))
            AND NOT (coalesce(oldstatus, '') = ANY (#{@paying_db}))
            AND NOT (coalesce(oldstatus, '') = ANY (#{@stopped_db}))
            AND NOT (coalesce(oldstatus, '') = ANY (#{@waiver_db}))
            then -1 else 0 end as othernet

        , 0 as membergain
        , case when
            coalesce(oldstatus, '') = ANY (#{@member_db})
            and (not coalesce(newstatus, '')  = ANY (#{@member_db}))
            then -1 else 0 end as memberloss
        , case when
            coalesce(oldstatus, '') = ANY (#{@member_db})
            then -1 else 0 end as membernet
        , 0 as othermembergain
        , case when
            coalesce(oldstatus, '') = ANY (#{@member_db})
            and coalesce(newstatus, '') = ANY (#{@member_db})
          then -1 else 0 end as othermemberloss

        -- orange members (user configurable but should be non fee paying)
        , 0 as orangegain
        , 0 as orangegain_nonmember
        , 0 as orangegain_member
        , case when
            coalesce(oldstatus, '') = ANY (#{@orange_db})
            and not coalesce(newstatus, '') = ANY (#{@orange_db})
            then -1 else 0 end as orangeloss
        , case when
            coalesce(oldstatus, '') = ANY (#{@orange_db})
            and not coalesce(newstatus, '') = ANY (#{@orange_db})
            and not coalesce(newstatus, '') = ANY (#{@member_db}) -- was an orange member and not not a member (exited waiver or stopped)
            then -1 else 0 end as orangeloss_nonmember
        , case when
            coalesce(oldstatus, '') = ANY (#{@orange_db})
            and not coalesce(newstatus, '') = ANY (#{@orange_db})
            and coalesce(newstatus, '') = ANY (#{@member_db}) -- was an orange member and now green (retained member)
            then -1 else 0 end as orangeloss_member
        , case when
            coalesce(oldstatus, '') = ANY (#{@orange_db})
            then -1 else 0 end as orangenet
        , 0 as otherorangegain
        , case when
            coalesce(newstatus, '') = ANY (#{@orange_db})
            and coalesce(oldstatus, '') = ANY (#{@orange_db})
          then -1 else 0 end as otherorangeloss

        -- green members (member inversion of orange - fee paying)
        , 0 as greengain
        , 0 as greengain_nonmember
        , 0 as greengain_member
        , case when
            coalesce(oldstatus, '') = ANY (#{@green_db})
            and not coalesce(newstatus, '') = ANY (#{@green_db})
            then -1 else 0 end as greenloss
        , case when
            coalesce(oldstatus, '') = ANY (#{@green_db})
            and not coalesce(newstatus, '') = ANY (#{@green_db})
            and not coalesce(newstatus, '') = ANY (#{@member_db}) -- green member now exited
            then -1 else 0 end as greenloss_nonmember
        , case when
            coalesce(oldstatus, '') = ANY (#{@green_db})
            and not coalesce(newstatus, '') = ANY (#{@green_db})
            and coalesce(newstatus, '') = ANY (#{@member_db}) -- green member now orange
            then -1 else 0 end as greenloss_member
        , case when
            coalesce(oldstatus, '') = ANY (#{@green_db})
            then -1 else 0 end as greennet
        , 0 as othergreengain
        , case when
            coalesce(newstatus, '') = ANY (#{@green_db})
            and coalesce(oldstatus, '') = ANY (#{@green_db})
          then -1 else 0 end as othergreenloss
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          , coalesce(old#{d.column_base_name}, '') #{d.column_base_name}
          , case when coalesce(old#{d.column_base_name}, '') <> coalesce(new#{d.column_base_name}, '')
              then -1 else 0 end as #{d.column_base_name}delta
    REPEAT

    sql << <<-SQL
        , nextstatuschange.nextchangeid _changeid
        , nextstatuschange.nextchangedate _changedate
        , nextstatuschange.nextduration duration
        , nextchange.nextchangeid nextchangeid
        , nextchange.nextchangedate nextchangedate
        , nextchange.nextduration changeduration
      from
        memberfact
        left join nextstatuschange on memberfact.changeid = nextstatuschange.changeid
        left join nextchange on memberfact.changeid = nextchange.changeid

      UNION ALL

      select
        memberfact.changeid
        , changedate
        , memberid
        , userid
        , 1 as net
        , 1 as gain
        , 0 as loss
        , coalesce(newstatus, '') as status
        , coalesce(oldstatus, '') as _status
        , case when
          (
            (
              coalesce(oldstatus, '') = ANY (#{@nonwaiver_db})
              or coalesce(newstatus, '') = ANY (#{@nonwaiver_db})
            )
            and coalesce(oldstatus, '') <> coalesce(newstatus, '') -- when changing between a1p, paying and stopped
          )
          or
          (
            (
              coalesce(oldstatus, '') = ANY (#{@waiver_db})
              and not coalesce(newstatus, '') = ANY (#{@waiver_db})
            )
            or
            (
              not coalesce(oldstatus, '') = ANY (#{@waiver_db})
              and coalesce(newstatus, '') = ANY (#{@waiver_db})
            )
          )
          then 1 else 0 end as statusdelta
        , case when not coalesce(oldstatus, '') = ANY (#{@a1p_db}) and coalesce(newstatus, '') = ANY (#{@a1p_db})
            then 1 else 0 end as a1pgain
        , 0 as a1ploss
        , case when coalesce(newstatus, '') = ANY (#{@a1p_db})
            then 1 else 0 end as a1pnet
        , case when not coalesce(oldstatus, '') = ANY (#{@paying_db}) and coalesce(newstatus, '') = ANY (#{@paying_db})
          then 1 else 0 end as payinggain
        , 0 as payingloss
        , case when coalesce(newstatus, '') = ANY (#{@paying_db})
          then 1 else 0 end as payingnet
        , case when not coalesce(oldstatus, '') = ANY (#{@stopped_db}) and coalesce(newstatus, '') = ANY (#{@stopped_db})
            then 1 else 0 end as stoppedgain
        , 0 as stoppedloss
        , case when coalesce(newstatus, '') = ANY (#{@stopped_db})
            then 1 else 0 end as stoppednet

        , case when not coalesce(oldstatus, '') = ANY (#{@waiver_db}) and coalesce(newstatus, '') = ANY (#{@waiver_db})
            then 1 else 0 end as waivergain
        , case when not coalesce(oldstatus, '') = ANY (#{@member_db}) and coalesce(newstatus, '') = ANY (#{@waiver_db})
            then 1 else 0 end as waivergaingood
        , case when coalesce(oldstatus, '') = ANY (#{@nonwaiver_db}) and coalesce(newstatus, '') = ANY (#{@waiver_db})
            then 1 else 0 end as waivergainbad
        , 0 as waiverloss
        , 0 as waiverlossgood
        , 0 as waiverlossbad
        , case when coalesce(newstatus, '') = ANY (#{@waiver_db})
            then 1 else 0 end as waivernet
        , case when
            NOT (not coalesce(oldstatus, '') = ANY (#{@a1p_db}) and coalesce(newstatus, '') = ANY (#{@a1p_db}))
            AND NOT (not coalesce(oldstatus, '') = ANY (#{@paying_db}) and coalesce(newstatus, '') = ANY (#{@paying_db}))
            AND NOT (not coalesce(oldstatus, '') = ANY (#{@stopped_db}) and coalesce(newstatus, '') = ANY (#{@stopped_db}))
            AND NOT (not coalesce(oldstatus, '') = ANY (#{@waiver_db}) and coalesce(newstatus, '') = ANY (#{@waiver_db}))
            then 1 else 0 end as othergain
        , 0 as otherloss
        , case when
            NOT (coalesce(newstatus, '') = ANY (#{@a1p_db}))
            AND NOT (coalesce(newstatus, '') = ANY (#{@paying_db}))
            AND NOT (coalesce(newstatus, '') = ANY (#{@stopped_db}))
            AND NOT (coalesce(newstatus, '') = ANY (#{@waiver_db}))
            then 1 else 0 end as othernet

        -- member gain, loss, net, other_gain, other_loss
        , case when
            (not coalesce(oldstatus, '') = ANY (#{@member_db}))
            and (coalesce(newstatus, '') = ANY (#{@member_db}))
            then 1 else 0 end as membergain
        , 0 as memberloss
        , case when
            coalesce(newstatus, '') = ANY (#{@member_db})
            then 1 else 0 end as membernet
        , case when
            coalesce(oldstatus, '') = ANY (#{@member_db})
            and coalesce(newstatus, '') = ANY (#{@member_db})
          then 1 else 0 end as othermembergain
        , 0 as othermemberloss

        -- orange members (user configurable but non fee paying)
        , case when
            (not coalesce(oldstatus, '') = ANY (#{@orange_db}))
            and (coalesce(newstatus, '') = ANY (#{@orange_db}))
            then 1 else 0 end as orangegain
        , case when
            not coalesce(oldstatus, '') = ANY (#{@orange_db})
            and coalesce(newstatus, '') = ANY (#{@orange_db})
            and not coalesce(oldstatus, '') = ANY (#{@member_db}) -- wasn't a member and now orange (straight to waiver like students)
            then 1 else 0 end as orangegain_nonmember
        , case when
            not coalesce(oldstatus, '') = ANY (#{@orange_db})
            and coalesce(newstatus, '') = ANY (#{@orange_db})
            and coalesce(oldstatus, '') = ANY (#{@member_db}) -- was a member (green) and now orange (problem)
            then 1 else 0 end as orangegain_member
        , 0 as orangeloss
        , 0 as orangeloss_nonmember
        , 0 as orangeloss_member
        , case when
            coalesce(newstatus, '') = ANY (#{@orange_db})
            then 1 else 0 end as orangenet
        , case when
            coalesce(oldstatus, '') = ANY (#{@orange_db})
            and coalesce(newstatus, '') = ANY (#{@orange_db})
          then 1 else 0 end as otherorangegain
        , 0 as otherorangeloss

        -- green members (member inversion of orange - fee paying)
        , case when
            (not coalesce(oldstatus, '') = ANY (#{@green_db}))
            and (coalesce(newstatus, '') = ANY (#{@green_db}))
            then 1 else 0 end as greengain
        , case when
            not coalesce(oldstatus, '') = ANY (#{@green_db})
            and coalesce(newstatus, '') = ANY (#{@green_db})
            and not coalesce(oldstatus, '') = ANY (#{@member_db}) -- wasn't a member and now green (new join)
            then 1 else 0 end as greengain_nonmember
        , case when
            not coalesce(oldstatus, '') = ANY (#{@green_db})
            and coalesce(newstatus, '') = ANY (#{@green_db})
            and coalesce(oldstatus, '') = ANY (#{@member_db}) -- was a member (green) and now green (retained)
            then 1 else 0 end as greengain_member
        , 0 as greenloss
        , 0 as greenloss_nonmember
        , 0 as greenloss_member
        , case when
            coalesce(newstatus, '') = ANY (#{@green_db})
            then 1 else 0 end as greennet
        , case when
            coalesce(oldstatus, '') = ANY (#{@green_db})
            and coalesce(newstatus, '') = ANY (#{@green_db})
          then 1 else 0 end as othergreengain
        , 0 as othergreenloss

    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          , coalesce(new#{d.column_base_name}, '') #{d.column_base_name}
          , case when coalesce(old#{d.column_base_name}, '') <> coalesce(new#{d.column_base_name}, '')
              then 1 else 0 end as #{d.column_base_name}delta
    REPEAT

    sql << <<-SQL
        , nextstatuschange.nextchangeid _changeid
        , nextstatuschange.nextchangedate _changedate
        , nextstatuschange.nextduration duration
        , nextchange.nextchangeid nextchangeid
        , nextchange.nextchangedate nextchangedate
        , nextchange.nextduration changeduration
      from
        memberfact
       left join nextstatuschange on memberfact.changeid = nextstatuschange.changeid
       left join nextchange on memberfact.changeid = nextchange.changeid

    SQL
  end

  def memberfacthelper_subset_sql
    <<-SQL
      (
        -- only include people who've been an interesting status
        exists (
          select
            1
          from
            memberfact mf
          where
            mf.memberid = h.memberid
            and (
              oldstatus = ANY (#{@member_db})
              or newstatus = ANY (#{@member_db})
            )
        )
        -- or have paid something since tracking begun
        or exists (
          select
            1
          from
            transactionfact tf
          where
            tf.memberid = h.memberid
        )
      )
    SQL
  end

  def memberfacthelper_sql
    sql = <<-SQL
      drop table if exists memberfacthelper cascade;
      create table memberfacthelper as
      select
        *
      from
        memberfacthelperquery h
      where
        #{memberfacthelper_subset_sql};
    SQL
  end

  def transactionfact_sql
    <<-SQL
      create table transactionfact
      (
        id varchar(255) not null
        , creationdate timestamp not null
        , memberid varchar(255) not null
        , userid varchar(255) not null
        , amount money not null
        , changeid bigint not null
      );
    SQL
  end

  def transactionfact
    db.ex(transactionfact_sql)
  end

  def transactionsource_sql
    sql = <<-SQL
      create table transactionsource
      (
        id varchar(255) not null primary key
        , creationdate timestamp not null
        , memberid varchar(255) not null
        , userid varchar(255) not null
        , amount money not null
      );

      create index idx_transactionsource_memberid on transactionsource(memberid);
    SQL

  end

  def rebuild_transactionsource_sql
    sql = <<-SQL
      drop table if exists transactionsource cascade;

      #{transactionsource_sql}
    SQL
  end

  def rebuild_transactionsource
    db.ex(rebuild_transactionsource_sql)
  end

   def transactionsourceprev_sql
    transactionsource_sql.gsub("transactionsource", "transactionsourceprev")
  end

  def transactionsourceprev
    db.ex(transactionsourceprev_sql)
  end

  def rebuild_transactionsourceprev_sql
    rebuild_transactionsource_sql.gsub("transactionsource", "transactionsourceprev")
  end

  def rebuild_transactionsourceprev
    db.ex(transactionsourceprev_sql)
  end

  def inserttransactionfact_sql
    <<-SQL
      CREATE OR REPLACE FUNCTION inserttransactionfact(import_date timestamp) RETURNS void
      AS $BODY$begin

        -- don't run the import if nothing has been imported for comparison
        if 0 = (SELECT count(*) FROM transactionsource) THEN
          return;
        END if;

        INSERT INTO
          transactionfact (
            id
            , creationdate
            , memberid
            , userid
            , amount
            , changeid
          );

        -- insert any transactions that have appeared since last comparison
        SELECT
          t.id
          , import_date
          , t.memberid
          , t.userid
          , t.amount
          , (
            -- assign dimensions of latest change to the transaction
            SELECT
              MAX(changeid) changeid
            FROM
              memberfact m
            WHERE
              m.memberid = t.memberid
          ) changeid
        FROM
          transactionSource t
          LEFT JOIN transactionSourcePrev p ON t.id = p.id
        WHERE
          p.id IS NULL
          AND t.memberid in (SELECT memberid FROM memberfact) -- TODO we really should handle transactions that have no member attached, rather than excluding them

        UNION ALL

        -- insert negations for any transactions that have been deleted since last comparison
        SELECT
          p.id
          , import_date
          , p.memberid
          , p.userid
          , 0::money-p.amount
          , (
            -- assign dimensions of deleted transaction to the negated transaction
            SELECT
              max(changeid) changeid
            FROM
              transactionfact
            WHERE
              transactionfact.id = p.id
          ) changeid
        FROM
          transactionSourcePrev p
          LEFT JOIN transactionSource t ON p.id = t.id
        WHERE
          t.id IS NULL
          -- Can only negate a transaction that we've recorded.
          AND p.id IN (SELECT id FROM transactionfact)

        -- finalise import, so running this again won't do anything
        DELETE FROM transactionSourcePrev;
        INSERT INTO transactionSourcePrev SELECT * FROM transactionSource;
        DELETE FROM transactionSource;
        analyse transactionsourceprev;

      END;$BODY$
        LANGUAGE plpgsql
        COST 100
        CALLED ON NULL INPUT
        SECURITY INVOKER
        VOLATILE;
    SQL
  end

  def updatedisplaytext_sql
    sql = <<-SQL
      CREATE OR REPLACE FUNCTION public.updatedisplaytext() RETURNS void
        AS $BODY$
      begin
        -- don't run the import if nothing is ready for comparison
        if 0 = (select count(*) from displaytextsource) then
          return;
        end if;


        update
          displaytext
        set
          id = case when lower(d2.attribute) in ('memberid', 'status') then d2.id else trim(lower(d2.id)) end
          , displaytext = d2.displaytext
        from
         displaytextsource d2
        where
          trim(lower(displaytext.id)) = trim(lower(d2.id))
          and displaytext.attribute = d2.attribute
          and (
            displaytext.displaytext <> d2.displaytext
            or displaytext.id <> d2.id
          )
        ;

        insert into displaytext(attribute, id, displaytext)
        select
          attribute
    , case when lower(attribute) in ('memberid', 'status') then id else trim(lower(id)) end
          , displaytext
        from
         displaytextsource d
        where
          not exists (select 1 from displaytext where attribute = d.attribute and trim(lower(id))=trim(lower(d.id)));

        -- delete to make way for next import
        delete from displaytextsource;
      end
      $BODY$
        LANGUAGE plpgsql
        COST 100
        CALLED ON NULL INPUT
        SECURITY INVOKER
        VOLATILE;
    SQL
  end

  def insertdisplaytext
    db.ex(insertdisplaytext_sql)
  end

  def rebuild_most_indexes_sql()
    sql = <<-SQL
      drop index if exists "displaytext_attribute_idx";
      drop index if exists "displaytext_id_idx";
      drop index if exists "displaytext_attribute_id_idx";

      drop index if exists "memberfact_changeid_idx";
      drop index if exists "memberfact_memberid_idx";
      drop index if exists "memberfact_oldstatus_idx";
      drop index if exists "memberfact_newstatus_idx";

      drop index if exists "transactionfact_memberid_idx";
      drop index if exists "transactionfact_changeid_idx";
    SQL


    sql << <<-SQL
      CREATE INDEX "displaytext_attribute_idx" ON "displaytext" USING btree(attribute ASC NULLS LAST);
      CREATE INDEX "displaytext_id_idx" ON "displaytext" USING btree(id ASC NULLS LAST);
      CREATE INDEX "displaytext_attribute_id_idx" ON "displaytext" USING btree(attribute ASC, id ASC NULLS LAST);
      CREATE INDEX "membersource_memberid_idx" ON "membersource" USING btree(memberid ASC NULLS LAST);

      CREATE INDEX "memberfact_changeid_idx" ON "memberfact" USING btree(changeid ASC NULLS LAST);
      CREATE INDEX "memberfact_memberid_idx" ON "memberfact" USING btree(memberid ASC NULLS LAST);
      CREATE INDEX "memberfact_oldstatus_idx" ON "memberfact" USING btree(oldstatus ASC NULLS LAST);
      CREATE INDEX "memberfact_newstatus_idx" ON "memberfact" USING btree(newstatus ASC NULLS LAST);


      CREATE INDEX "transactionfact_memberid_idx" ON "transactionfact" USING btree(memberid ASC NULLS LAST);
      CREATE INDEX "transactionfact_changeid_idx" ON "transactionfact" USING btree(changeid ASC NULLS LAST);
    SQL
  end

  def rebuild_memberfacthelper_indexes_sql()
    sql = ""
    dimensions.each { |d| sql << <<-REPEAT }
      drop index if exists "memberfacthelper_#{d.column_base_name}_idx" ;
    REPEAT

    sql << <<-SQL
      drop index if exists "memberfacthelper_changeid_idx";
      drop index if exists "memberfacthelper_memberid_idx";
      drop index if exists "memberfacthelper_changedate_idx";
      drop index if exists "memberfacthelper_nextchangedate_idx";

      CREATE INDEX "memberfacthelper_changeid_idx" ON "memberfacthelper" USING btree(changeid ASC NULLS LAST);
      CREATE INDEX "memberfacthelper_memberid_idx" ON "memberfacthelper" USING btree(memberid ASC NULLS LAST);
      CREATE INDEX "memberfacthelper_changedate_idx" ON "memberfacthelper" USING btree(changedate ASC NULLS LAST);
      CREATE INDEX "memberfacthelper_nextchangedate_idx" ON "memberfacthelper" USING btree(nextchangedate ASC NULLS LAST);
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
      CREATE INDEX "memberfacthelper_#{d.column_base_name}_idx" ON "memberfacthelper" USING btree(#{d.column_base_name} ASC NULLS LAST);
    REPEAT

    sql
  end

  def migrate_membersourceprev_sql(mapping)

    sql = <<-SQL

      insert into membersourceprev
      (
        memberid
        , userid
        , status
    SQL

    mapping.each { | oldvalue, newvalue | sql << <<-REPEAT }
        , #{newvalue}
    REPEAT

    sql << <<-SQL
      )
      select
        memberid
        , userid --replace_me
        , status
    SQL

    mapping.each { | oldvalue, newvalue | sql << <<-REPEAT }
        , trim(lower(#{oldvalue}::text))
    REPEAT

    sql << <<-SQL
      from
        membersourceprev_migration;
    SQL
  end


  def migrate_memberfact_sql(mapping)

    sql = <<-SQL

      insert into memberfact
      (
        changeid
        , changedate
        , memberid
        , userid
        , oldstatus
        , newstatus
    SQL

    mapping.each { | oldvalue, newvalue | sql << <<-REPEAT }
        , old#{newvalue}
        , new#{newvalue}
    REPEAT

    sql << <<-SQL
      )
      select
        changeid
        , changedate
        , memberid
        , userid --replace_me
        , oldstatus
        , newstatus
    SQL

    mapping.each { | oldvalue, newvalue | sql << <<-REPEAT }
        , trim(lower(old#{oldvalue}::text))
        , trim(lower(new#{oldvalue}::text))
    REPEAT

    sql << <<-SQL
      from
        memberfact_migration;

      SELECT setval('memberfact_changeid_seq', (SELECT MAX(changeid) FROM memberfact));
    SQL
  end

  # ASU to NUW back-porting migration
  def migrate_nuw_transactionfact_sql
    <<-SQL

      insert into transactionfact
      (
        id
        , creationdate
        , memberid
        , userid
        , amount
        , changeid
      )
      select
        transactionid
        , creationdate
        , memberid
        , staffid
        , coalesce(amount,0::money)
        , changeid
      from
        transactionfact_migration;
    SQL
  end

  # ASU to NUW back-porting migration
  def migrate_nuw_transactionsourceprev_sql
    <<-SQL

      insert into transactionsourceprev
      (
        id
        , creationdate
        , memberid
        , userid
        , amount
      )
      select
        transactionid
        , creationdate
        , memberid
        , staffid
        , coalesce(amount,0::money)
      from
        transactionsourceprev_migration;
    SQL
  end

  # ASU to NUW back-porting migration
  def migrate_nuw_displaytext_sql
    <<-SQL

      insert into displaytext
      (
        attribute
        , id
        , displaytext
      )
      select
        attribute
        , case when lower(attribute) in ('memberid', 'status') then id else trim(lower(id)) end
        , displaytext
      from
        displaytext_migration;
    SQL
  end


  def migrate_dimstart_sql(migration_spec)
    sql = ""

    migration_spec.each do | k, v |
      case v.to_s
      when "CREATE"
        sql << "insert into dimstart (dimension, startdate) select '#{k.to_s}', current_date; \n";
      when "DELETE"
        sql << "delete from dimstart where dimension = '#{k.to_s}'; \n" ;
      else
        sql << "update dimstart set dimension = '#{v.to_s}' where dimension = '#{k.to_s}'; \n" if (k.to_s != v.to_s);
        sql << "update displaytext set attribute = '#{v.to_s}' where attribute = '#{k.to_s}'; \n" if (k.to_s != v.to_s);
      end
    end
    sql
  end

  # Returns true if the use of the config of the 'app' passed to this instance would necessitate a
  # database migration because of a change in the way that the memberfacthelper is generated.
  def memberfacthelper_migration_required?
    @db.get_app_state('memberfacthelperquery_source') != memberfacthelperquery_sql()
  end

  def migration_spec_all
    m = {}

    # retreive current db schema, action = delete by default
    columns = db.ex("select column_name from information_schema.columns where table_name='membersourceprev';")
    columns.each do |row|
      if !['memberid', 'status', 'userid'].include?(row['column_name'])
        m[row['column_name']] = 'DELETE'
      end
    end

    # match dimensions to db columns, if a dimensions isn't in db list, create it
    # any unmatched db columns, will remain deleted
    dimensions().each do | d |
      if m.has_key?(d.column_base_name)
        m[d.column_base_name] = d.column_base_name
      else
        m[d.column_base_name] = 'CREATE' if d.column_base_name != 'userid'
      end
    end

    m
  end

  def migration_yaml_spec
    all = migration_spec_all()
    if (all.count{ |k,v| v == 'DELETE' || v == 'CREATE' } > 0)
      all.to_yaml
    else
      nil
    end
  end

  def parse_migration(yaml_spec)
    migration_spec = YAML.load(yaml_spec)

    # make sure columns being mapped are present in both db and config
    mapping = migration_spec.select{ |k,v| v.to_s != "DELETE" && v.to_s != "CREATE"}
    dimension_names = dimensions.collect { |d| d.column_base_name }

    column_data = db.ex("select column_name from information_schema.columns where table_name='membersourceprev' and column_name <> 'userid';")
    columns = column_data.collect { |row| row['column_name'] }

    mapping.each do |k,v|
      raise "Reporting dimension #{v} not found in config/config.yaml" if !dimension_names.include?(v)
      raise "Reporting dimension #{k} not found in database" if !columns.include?(k)
    end

    migration_spec
  end

  # ASU to NUW specific migration (replaced below!)
  def migrate_nuw_sql(migration_spec)
    mapping = migration_spec.select{ |k,v| v.to_s != "DELETE" && v.to_s != "CREATE"}

    [ '-- nuw migration',
      rebuild_from_scratch_without_indexes_sql(),
      '-- start of nuw data migration',
      migrate_membersourceprev_sql(mapping).gsub(', userid --replace_me', ', statusstaffid'),
      migrate_memberfact_sql(mapping).gsub(', userid --replace_me', ', newstatusstaffid'),
      migrate_nuw_transactionfact_sql(),
      migrate_nuw_transactionsourceprev_sql(),
      migrate_nuw_displaytext_sql(),
      migrate_dimstart_sql(migration_spec)
    ] + rebuild_most_indexes_sql().split($/) +
    [
      <<-SQL
      insert into dimstart (dimension, startdate)  select 'userid', '2012-04-27' where not exists (select 1 from dimstart where dimension = 'userid');
      update displaytext set attribute = 'userid' where attribute = 'statusstaffid';

      update memberfacthelper set userid = lower(userid) where coalesce(userid,'') <> coalesce(lower(userid),'');
      update memberfact set userid = lower(userid) where coalesce(userid,'') <> coalesce(lower(userid),'');
      update transactionfact set userid = lower(userid) where coalesce(userid,'') <> coalesce(lower(userid),'');

      select updatememberfacthelper();
      drop table if exists memberid_detail;

      select
        d.id
        , displaytext
        , contactdetail
        , followupnotes
      into
        memberid_detail
      from
        displaytext d left join membersourceprev_migration m on trim(d.id) = trim(m.memberid)

      where
        d.attribute = 'memberid';

      create index memberid_detail_id_idx on memberid_detail (id);
    SQL
      ]
  end

    def migrate_asu_sql(migration_spec)
    mapping = migration_spec.select{ |k,v| v.to_s != "DELETE" && v.to_s != "CREATE"}

    [
      '-- asu migration',
      migrate_rebuild_without_indexes_sql(),
      '-- start of migration',
      migrate_membersourceprev_sql(mapping).gsub(', userid --replace_me', ', null'),
      migrate_memberfact_sql(mapping).gsub(', userid --replace_me', ', null'),
      migrate_dimstart_sql(migration_spec)
    ] + rebuild_most_indexes_sql().split($/)
  end

  # Returns an array of sql statements.
  def migrate_sql(migration_spec)
    mapping = migration_spec.select{ |k,v| v.to_s != "DELETE" && v.to_s != "CREATE"}

#      -- regular migration
      [migrate_rebuild_without_indexes_sql(),
      migrate_membersourceprev_sql(mapping).gsub(', userid --replace_me', ', userid'),
      migrate_memberfact_sql(mapping).gsub(', userid --replace_me', ', userid'),
      migrate_dimstart_sql(migration_spec)
      ] + rebuild_most_indexes_sql().split($/)
  end

  # migration_sql_ary: an array of sql statements to execute
  # Raises an exception if a critical error occurred that prevented the migration from succeeding.
  # Returns true on success, or an error string in the case of a recoverable error.
  def migrate(migration_sql_ary, update_memberfacthelper_and_indexes = true)
    begin
      # This method needs to run with async_ex so that other ruby threads can run while the migration
      # operates. However, async_ex blocks other threads (even though it shouldn't) when several SQL
      # operations are passed in a single batch. This is the reason for use of arrays and for the
      # splitting of long statements by line break -- so that large statements can be reduced to a
      # series of smaller ones.
      db.async_ex("BEGIN TRANSACTION");

      migration_sql_ary.each { |sql| $stderr.puts sql; db.async_ex(sql) }

    # with lots of data memberfacthelper can be impossibly slow to rebuild
      if update_memberfacthelper_and_indexes
        db.async_ex("select updatememberfacthelper();");
        rebuild_memberfacthelper_indexes_sql().split($/).each { |sql| $stderr.puts sql; db.async_ex(sql); }
      end

      db.async_ex("COMMIT TRANSACTION");
    rescue Exception=>e
      $stderr.puts e
      db.async_ex("ROLLBACK TRANSACTION");
      raise
    end

    db.set_app_state('memberfacthelperquery_source', memberfacthelperquery_sql())

    finalisation_statements =
      ["vacuum full memberfact",
       "vacuum full membersourceprev",
       "vacuum full transactionfact",
       "vacuum full transactionsourceprev",
       "vacuum full displaytext",
       "vacuum full memberfacthelper",

       "analyse memberfact",
       "analyse membersourceprev",
       "analyse transactionfact",
       "analyse transactionsourceprev",
       "analyse displaytext",
       "analyse memberfacthelper"]

    current_statement = nil

    begin
      finalisation_statements.each do |sql|
        $stderr.puts sql
        current_statement = sql
        db.async_ex(sql)
      end
    rescue Exception=>e
      return <<EOS
There was an error while finalising the migration. SQL statement: '#{current_statement}'.
Exception message: #{e.message}
The migration succeeded, but the database may run with reduced performance until the following SQL has been executed:
#{finalisation_statements.join($/)}
EOS
    end

    true
  end

  def backdate_sql(columns, back_to)
    dn = dimensions().collect { |d| d.column_base_name }
    <<-SQL
      <PRE>
      -- Back dating #{columns} to #{back_to}
      -- I was hoping to make a generic backdating script, except
      -- instead this can only backdate columns that a functionally
      -- dependent of companyid. e.g. lead, io, team, industryid

      begin transaction;

      -- set new dimensions to the back_to
      update dimstart set startdate = '#{back_to}'::date where startdate = current_date;

      -- manual backdate of unionid
      update memberfact set newunionid = 'nuw' where not newstatus is NULL;
      update memberfact set oldunionid = 'nuw' where not oldstatus is NULL;
      update dimstart set startdate = '2017-12-31' where dimension = 'unionid';


      DROP TABLE IF EXISTS bd_current;
      SELECT distinct
        lower(companyid) companyid
        , #{columns.collect{|d| "lower(#{d}) #{d}"}.join("\n        , ")}
      INTO
        bd_current
      FROM
        membersource
      where
        lower(branchid) in ('nv', 'ng', 'na')
      order by
        companyid;

      commit transaction;

      select count(*) from bd_current; -- did you import the latest member.txt into membersource?
      select * from bd_current; -- do you have all columns functionally dependent on companyid?

      select count(*) from memberfact where changedate::date = '#{back_to}'::date; -- take note
      select count(*) from memberfact where changedate > '#{back_to}'::date + interval '1 day'; -- take note
      select count(*) from transactionfact where changeid not in (select changeid from memberfact); -- take note

      begin transaction;
      INSERT INTO
        memberfact
        (
          changedate
          , memberid
          , userid
          , oldstatus
          , newstatus
          #{dn.collect{|d|<<-D}.join("")}
          , old#{d}
          , new#{d}
          D
        )
      SELECT
        coalesce((select max(changedate) from memberfact where changedate::date = '#{back_to}'::date ), '#{back_to}'::timestamp) + interval '1 second'
        , m.memberid
        , m.userid
        , m.newstatus
        , m.newstatus
        #{dn.collect{|d|<<-D}.join("")}
        , m.new#{d}
        , #{columns.include?(d) ? "c.#{d}" : "m.new#{d}" }
        D
      FROM
        memberfact m
        inner join bd_current c on m.newcompanyid = c.companyid
      where
        coalesce(m.newcompanyid, '') <> ''
        and m.changeid in (select max(changeid) from memberfact where changedate < '#{back_to}'::date + interval '1 day' group by memberid)
        and (#{columns.collect {|d| "coalesce(c.#{d},'') <> coalesce(m.new#{d},'') "}.join(" OR ")})
      ;

      update
        memberfact
      set
        #{columns.collect{|d| "new#{d} = c.#{d}" }.join("\n        , ")}
      from
        bd_current c
      where
        memberfact.newcompanyid = c.companyid
        and memberfact.changedate > '#{back_to}'::date + interval '1 day';

      update
        memberfact
      set
        #{columns.collect{|d| "old#{d} = c.#{d}" }.join("\n        , ")}
      from
        bd_current c
      where
        memberfact.oldcompanyid = c.companyid
        and memberfact.changedate > '#{back_to}'::date + interval '1 day';




      alter table memberfact add column initial_changeid bigint;

      with redundant as (
        select
          *
        from
          memberfact m
        where
          coalesce(m.oldstatus,'') = coalesce(m.newstatus,'')
          AND #{dn.collect {|d| "coalesce(m.old#{d},'') = coalesce(m.new#{d},'') "}.join("\n        AND ")}
      --  limit 3
      )
      update
        memberfact
      set
        initial_changeid = r3.changeid
      --select
        --r1.memberid
        --, r1.changedate
        --, r1.changeid
        --, r3.changedate
        --, r3.changeid
      from
        memberfact r1
        left join lateral (
          select
            *
          from
            memberfact r2
          where
            not r2.changeid in (select changeid from redundant)
            and r2.changedate <= r1.changedate
            and r2.memberid = r1.memberid
          order by
            changedate desc
          limit 1
        ) r3 on true
      where
        r1.memberid in (select memberid from redundant)
        and r1.changeid <> r3.changeid
        and r1.changeid = memberfact.changeid
      ;

      alter table memberfact add column old_changeid bigint;
      update memberfact set old_changeid = changeid;
      select * into bd_memberfact from memberfact;
      delete from memberfact;
      alter sequence memberfact_changeid_seq restart with 1;

      INSERT INTO
        memberfact
        (
          changedate
          , old_changeid
          , memberid
          , userid
          , oldstatus
          , newstatus
          #{dn.collect{|d|<<-D}.join("")}
          , old#{d}
          , new#{d}
          D
        )
      select
        changedate
        , old_changeid
        , memberid
        , userid
        , oldstatus
        , newstatus
        #{dn.collect{|d|<<-D}.join("")}
        , old#{d}
        , new#{d}
        D
      from
        bd_memberfact
      where
        initial_changeid IS NULL -- remove redundant changes
      order by
        changedate;

      update
        transactionfact
      set
        changeid = m.initial_changeid
      FROM
        bd_memberfact m
      where
        m.changeid = transactionfact.changeid
        and not m.initial_changeid IS NULL;

      update
        transactionfact
      set
        changeid = m.changeid
      FROM
        memberfact m
      where
        m.old_changeid = transactionfact.changeid;

      commit transaction;

      /*
      -- manually step through this stuff
      select count(*) from memberfact where changedate::date = '#{back_to}'::date; -- is this about the number of members that have companyids?
      select count(*) from memberfact where changedate > '#{back_to}'::date + interval '1 day'; -- is this the right amount lower to get rid of redundant changes
      select count(*) from transactionfact where changeid not in (select changeid from memberfact); -- is this still about the same?

      alter table memberfact drop column initial_changeid, drop column old_changeid;

      vacuum full analyse memberfact;
      vacuum full analyse transactionfact;

      delete from memberfacthelper;
      select updatememberfacthelper();

      vacuum full analyse memberfacthelper;
      select count(*) from memberfacthelper where changedate > '#{back_to}'::date + interval '1 day'; -- is it low?

      drop table bd_current;
      drop table bd_memberfact;

      drop table memberfact_migration;
      drop table memberfacthelper_migration;
      drop table membersourceprev_migration;
      drop table memberfactbackupfrom13feb;
      */

      </PRE>
    SQL
  end
end
