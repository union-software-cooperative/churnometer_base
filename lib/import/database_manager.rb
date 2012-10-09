require './lib/churn_db'
require 'open3.rb'

class DatabaseManager
  
  def db 
    @db ||= Db.new
  end

  def dimensions
    @dimensions ||= Dimensions.new # Stub of David's dimension class
  end

  def rebuild_sql()
    sql = <<-SQL
      drop table if exists importing;
      select 0 as importing into importing;
   
      drop function if exists insertmemberfact();
      drop function if exists inserttransactionfact();
      drop function if exists updatedisplaytext();
      drop function if exists updatememberfacthelper();
      
      drop view if exists memberchangefromlastchange;
      drop view if exists lastchange;
      drop view if exists memberfacthelperquery;

      drop table if exists memberfact_migration;
      drop table if exists transactionfact_migration;
      drop table if exists displaytext_migration;
      drop table if exists memberfacthelper_migration;
      
	    alter table memberfact rename to memberfact_migration;
      alter table transactionfact rename to transactionfact_migration;
      alter table displaytext rename to displaytext_migration;
      alter table memberfacthelper rename to memberfacthelper_migration;
     
      #{rebuild_displaytextsource_sql};
      #{rebuild_transactionsource_sql};
      #{rebuild_transactionsourceprev_sql};
      #{rebuild_membersource_sql};
      #{rebuild_membersourceprev_sql};
      
      #{memberfact_sql};
      #{transactionfact_sql};
      #{displaytext_sql};
      
      #{lastchange_sql};
      #{memberchangefromlastchange_sql};
      #{memberfacthelperquery_sql};
      #{memberfacthelper_sql}
      
      #{updatedisplaytext_sql};
      #{updatememberfacthelper_sql};
      #{insertmemberfact_sql};
      #{inserttransactionfact_sql};      
    SQL
  end
  
  def rebuild()
    db.ex(rebuild_sql)
    
    # ANALYSE and VACUUM have to be run as separate database calls
    str = <<-SQL
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
      
      VACUUM memberfact;
      VACUUM memberfacthelper;
      VACUUM transactionfact;
      VACUUM displaytext;
      VACUUM membersource;
      VACUUM membersourceprev;
      VACUUM transactionsource;
      VACUUM transactionsourceprev;
      VACUUM displaytextsource;
    SQL
    
    str.split("\n").each { |cmd| db.ex(cmd) }
  end
  
  def rebuild_displaytextsource_sql
    sql = <<-SQL
      drop table if exists displaytextsource;
      
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
      
      DROP INDEX "displaytext_attribute_idx";
	    DROP INDEX "displaytext_id_idx";
      DROP INDEX "displaytext_attribute_id_idx";

      CREATE INDEX "displaytext_attribute_idx" ON "displaytext" USING btree(attribute ASC NULLS LAST);
      CREATE INDEX "displaytext_id_idx" ON "displaytext" USING btree(id ASC NULLS LAST);
      CREATE INDEX "displaytext_attribute_id_idx" ON "displaytext" USING btree(attribute ASC, id ASC NULLS LAST);
    
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
        , status varchar(255) not null
    SQL
  
    dimensions.each { |d| sql << <<-REPEAT } 
        , #{d.column_base_name} varchar(255) null
    REPEAT
    
    sql << <<-SQL
      )
      
    SQL
  end
  
  def rebuild_membersource_sql
    sql = <<-SQL
      drop table if exists membersource;
    
      #{membersource_sql}
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
    sql << <<-SQL
      ; CREATE INDEX "membersourceprev_memberid_idx" ON "membersourceprev" USING btree(memberid ASC NULLS LAST);
    SQL
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
        , oldstatus varchar(255) null
        , newstatus varchar(255) null
    SQL

    dimensions.each { | d | sql << <<-REPEAT }
        , old#{d.column_base_name} varchar(255) null
        , new#{d.column_base_name} varchar(255) null
    REPEAT

    sql << <<-SQL
      );
      
      DROP INDEX "memberfact_changeid_idx";
      DROP INDEX "memberfact_memberid_idx";
      DROP INDEX "memberfact_oldstatus_idx";
      DROP INDEX "memberfact_newstatus_idx";
      
      CREATE INDEX "memberfact_changeid_idx" ON "memberfact" USING btree(changeid ASC NULLS LAST);
      CREATE INDEX "memberfact_memberid_idx" ON "memberfact" USING btree(memberid ASC NULLS LAST);
      CREATE INDEX "memberfact_oldstatus_idx" ON "memberfact" USING btree(oldstatus ASC NULLS LAST);
      CREATE INDEX "memberfact_newstatus_idx" ON "memberfact" USING btree(newstatus ASC NULLS LAST);
    SQL
  end

  def lastchange_sql
    sql = <<-SQL
      create view lastchange as
        select
          changeid
          , changedate
          , memberid
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

  def memberchangefromlastchange_sql

    sql = <<-SQL
      -- find changes, adds and deletions in latest data
      create view memberchangefromlastchange as 
      -- find members who've changed in latest data
      select
        now() as changedate
        , old.memberid
        , old.status as oldstatus
        , new.status as newstatus
    SQL
    
    dimensions.each { |d| sql << <<-REPEAT }
        , old.#{d.column_base_name} as old#{d.column_base_name}
        , new.#{d.column_base_name} as new#{d.column_base_name}
    REPEAT

    sql << <<-SQL
      from
        lastchange old
        inner join membersource new on old.memberid = new.memberid
      where
        1=0 -- so I don't have to stript the following OR
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        OR coalesce(old.#{d.column_base_name}, '') <> coalesce(new.#{d.column_base_name}) 
    REPEAT
    
    sql << <<-SQL
      UNION ALL
      -- find members missing in latest data
      select
        now() as changedate
        , old.memberid
        , old.status as oldstatus
        , null as newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        , old.#{d.column_base_name} as old#{d.column_base_name}
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
          old.status is null
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          AND old.#{d.column_base_name} is null
    REPEAT

    sql << <<-SQL
        )
      UNION ALL
      -- find members appearing in latest data
      select
        now() as changedate
        , new.memberid
        , null as oldstatus
        , new.status as newstatus
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
        , null as old#{d.column_base_name}
        , new.#{d.column_base_name} as new#{d.column_base_name}
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
              oldstatus = 'paying'
              or oldstatus = 'stopped'
              or oldstatus = 'a1p'
              or newstatus = 'paying'
              or newstatus = 'stopped'
              or newstatus = 'a1p'
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
        from
          memberfacthelperquery h
        where
          memberfacthelper.changeid = h.changeid
          and memberfacthelper.net = h.net
          and (
            coalesce(memberfacthelper.duration,0) <> coalesce(h.duration,0)
            or coalesce(memberfacthelper._changeid,0) <> coalesce(h._changeid,0)
            or coalesce(memberfacthelper._changedate, '1/1/1900') <> coalesce(h._changedate, '1/1/1900') 
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
      , nextchange as (
        select 
          c.changeid
          , n.changeid nextchangeid
          , n.changedate nextchangedate
          , n.newstatus nextstatus
          , (coalesce(n.changedate::date, current_date) - c.changedate::date)::int nextduration
        from 
          mfnextstatuschange c
        left join memberfact n on c.nextstatuschangeid = n.changeid
      )
      select
        memberfact.changeid
        , changedate
        , memberid      
        , -1 as net
        , 0 as gain
        , 1 as loss
        , coalesce(oldstatus, '') as status
        , coalesce(newstatus, '') as _status
        , case when coalesce(oldstatus, '') <> coalesce(newstatus, '')
            then -1 else 0 end as statusdelta
        , 0 as a1pgain
        , case when coalesce(oldstatus, '') = 'a1p' and coalesce(newstatus, '') <> 'a1p'
            then -1 else 0 end as a1ploss
        , 0 as payinggain
        , case when coalesce(oldstatus, '') = 'paying' and coalesce(newstatus, '') <> 'paying'
          then -1 else 0 end as payingloss
        , 0 as stoppedgain
        , case when coalesce(oldstatus, '') = 'stopped' and coalesce(newstatus, '') <> 'stopped'
            then -1 else 0 end as stoppedloss
        , 0 as othergain
        , case when 
            NOT coalesce(oldstatus, '') = 'a1p' and coalesce(newstatus, '') <> 'a1p'
            AND NOT coalesce(oldstatus, '') = 'paying' and coalesce(newstatus, '') <> 'paying'
            AND NOT coalesce(oldstatus, '') = 'stopped' and coalesce(newstatus, '') <> 'stopped'
            then -1 else 0 end as otherloss
    SQL
  
    dimensions.each { |d| sql << <<-REPEAT }
          , coalesce(old#{d.column_base_name}, '') #{d.column_base_name}
          , case when coalesce(old#{d.column_base_name}, '') <> coalesce(new#{d.column_base_name}, '')
              then -1 else 0 end as #{d.column_base_name}delta 
    REPEAT

    sql << <<-SQL
        , nextchangeid _changeid
        , nextchangedate _changedate
        , nextduration duration
      from 
        memberfact
        inner join nextchange on memberfact.changeid = nextchange.changeid

      UNION ALL

      select
        memberfact.changeid
        , changedate
        , memberid
        , 1 as net
        , 1 as gain
        , 0 as loss
        , coalesce(newstatus, '') as status
        , coalesce(oldstatus, '') as _status
        , case when coalesce(oldstatus, '') <> coalesce(newstatus, '')
            then 1 else 0 end as statusdelta
        , case when coalesce(oldstatus, '') = 'a1p' and coalesce(newstatus, '') <> 'a1p'
            then 1 else 0 end as a1pgain
        , 0 as a1ploss
        , case when coalesce(oldstatus, '') = 'paying' and coalesce(newstatus, '') <> 'paying'
          then 1 else 0 end as payinggain
        , 0 as payingloss
        , case when coalesce(oldstatus, '') = 'stopped' and coalesce(newstatus, '') <> 'stopped'
            then 1 else 0 end as stoppedgain
        , 0 as stoppedloss
        , case when 
            NOT coalesce(oldstatus, '') = 'a1p' and coalesce(newstatus, '') <> 'a1p'
            AND NOT coalesce(oldstatus, '') = 'paying' and coalesce(newstatus, '') <> 'paying'
            AND NOT coalesce(oldstatus, '') = 'stopped' and coalesce(newstatus, '') <> 'stopped'
            then 1 else 0 end as othergain
        , 0 as otherloss
    SQL
  
    dimensions.each { |d| sql << <<-REPEAT }
          , coalesce(new#{d.column_base_name}, '') #{d.column_base_name}
          , case when coalesce(old#{d.column_base_name}, '') <> coalesce(new#{d.column_base_name}, '')
              then 1 else 0 end as #{d.column_base_name}delta 
    REPEAT

    sql << <<-SQL
        , nextchangeid _changeid
        , nextchangedate _changedate
        , nextduration duration
      from 
        memberfact
        inner join nextchange on memberfact.changeid = nextchange.changeid
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
              oldstatus = 'paying'
              or oldstatus = 'stopped'
              or oldstatus = 'a1p'
              or newstatus = 'paying'
              or newstatus = 'stopped'
              or newstatus = 'a1p'
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
      drop table if exists memberfacthelper;
      create table memberfacthelper as 
      select 
        * 
      from 
        memberfacthelperquery h
      where 
        #{memberfacthelper_subset_sql};
        
    DROP INDEX "memberfacthelper_changeid_idx";
    DROP INDEX "memberfacthelper_memberid_idx";
    DROP INDEX "memberfacthelper_changedate_idx";
    
    CREATE INDEX "memberfacthelper_changeid_idx" ON "memberfacthelper" USING btree(changeid ASC NULLS LAST);
    CREATE INDEX "memberfacthelper_memberid_idx" ON "memberfacthelper" USING btree(memberid ASC NULLS LAST);
    CREATE INDEX "memberfacthelper_changedate_idx" ON "memberfacthelper" USING btree(changedate ASC NULLS LAST);
    SQL
    
    dimensions.each { |d| sql << <<-REPEAT }
      DROP INDEX "memberfacthelper_#{d.column_base_name}_idx" ;
      CREATE INDEX "memberfacthelper_#{d.column_base_name}_idx" ON "memberfacthelper" USING btree(#{d.column_base_name} ASC NULLS LAST);
    REPEAT
    
    sql
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
      
      DROP INDEX "transactionfact_memberid_idx";
      DROP INDEX "transactionfact_changeid_idx";
      CREATE INDEX "transactionfact_memberid_idx" ON "transactionfact" USING btree(memberid ASC NULLS LAST);
      CREATE INDEX "transactionfact_changeid_idx" ON "transactionfact" USING btree(changeid ASC NULLS LAST);
    SQL
    
  end
  
  def transactionfact
    db.ex(transactionfact_sql)
  end
  
  def transactionsource_sql
    sql = <<-SQL
      create table transactionsource
      (
        id varchar(255) not null
        , creationdate timestamp not null
        , memberid varchar(255) not null
        , userid varchar(255) not null
        , amount money not null
      );
    SQL
  end
  
  def rebuild_transactionsource_sql
    sql = <<-SQL
      drop table if exists transactionsource;
      
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
        if 0 = (select count(*) from transactionsource) then 
          return;
        end if;  
        
        insert into 
          transactionfact (
              id
              , creationdate
              , memberid
              , userid 
              , amount
              , changeid
            )
            
        -- insert any transactions that have appeared since last comparison
        select 
          t.id
          , import_date 
          , t.memberid
          , t.userid
          , t.amount
          , (
            -- assign dimensions of latest change to the transaction
            select 
              max(changeid) changeid 
            from 
              memberfact m 
            where 
              m.memberid = t.memberid
          ) changeid
        from 
          transactionSource t 
        where 
          not id in (select id from transactionSourcePrev)
          
        union all
        
        -- insert negations for any transactions that have been deleted since last comparison
        select 
          t.id
          , import_date
          , t.memberid
          , t.userid
          , 0::money-t.amount
          , (
            -- assign dimensions of deleted transaction to the negated transaction
            select 
              changeid
            from
              transactionfact
            where
              transactionfact.id = t.id
          ) changeid
        from 
          transactionSourcePrev t 
        where 
          not id in (select id from transactionSource)  
        ;
        
        -- finalise import, so running this again won't do anything
        delete from transactionSourcePrev;
        insert into transactionSourcePrev select * from transactionSource;
        delete from transactionSource;
        
      end;$BODY$
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
          displaytext = d2.displaytext
        from
         displaytextsource d2  
        where
          displaytext.id = d2.id 
          and displaytext.attribute = d2.attribute
          and displaytext.displaytext <> d2.displaytext
        ;
        
        insert into displaytext
        select
          *
        from
         displaytextsource d
        where
          not exists (select 1 from displaytext where attribute = d.attribute and id=d.id);
        
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
end
