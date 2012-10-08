require './lib/churn_db'
require 'open3.rb'

class DatabaseManager
  
  def db 
    @db ||= Db.new
  end

  def dimensions
    @dimensions ||= Dimensions.new # Stub of David's dimension class
  end

  def migratecols_sql()
    sql = <<-SQL
      drop function if exists insertmemberfact();
      drop view if exists memberchangefromlastchange;
      drop view if exists lastchange;
      drop view if exists memberfacthelperquery;

      drop table if exists membersourceprev_migration;
      drop table if exists memberfact_migration;
      
	    alter table membersourceprev rename to membersourceprev_migration;
      alter table memberfact rename to memberfact_migration;
     
      drop table if exists membersource;
      
      #{rebuild_displaytextsource_sql};
      #{rebuild_transactionsource_sql};
      #{rebuild_membersource_sql};
      #{rebuild_membersourceprev_sql};
      #{memberfact_sql};
      #{lastchange_sql};
      #{memberchangefromlastchange_sql};
      #{memberfacthelperquery_sql};
      #{insertmemberfact_sql};
    SQL
  end
  
  def migratecols()
    db.ex(migratecols_sql)
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
    rebuild_membersource_sql.sub('membersource', 'membersourceprev')
  end
  
  def rebuild_membersourceprev
    db.ex(rebuild_membersourceprev_sql)
  end

  def memberfact
    sql = <<-SQL
      create table memberfact
      (
        changeid BIGSERIAL PRIMARY KEY
        , changedate timestamp not null
        , memberid varchar(255) not null
        , oldstatus varchar(255) null
        , newstatus varchar(255) null
    SQL

    dimensions.each { | i | sql << <<-REPEAT }
        , old#{d.column_base_name} varchar(255) null
        , new#{d.column_base_name} varchar(255) null
    REPEAT

    sql << <<-SQL
      )
    SQL
  end

  def lastchange
    sql = <<-SQL
      create view lastchange as
        select
          changeid
          , changedate
          , memberid
          , newstatus status
    SQL

    dimensions.each { |d| sql << <<-REPEAT }
          , new#{d.column_base_name} as col#{d.column_base_name}
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

  def memberchangefromlastchange

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

  def insertmemberfact

    sql = <<-SQL
      CREATE OR REPLACE FUNCTION insertmemberfact() RETURNS void 
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
        from
          memberchangefromlastchange;

      end$BODY$
      LANGUAGE plpgsql
	    COST 100
	    CALLED ON NULL INPUT
	    SECURITY INVOKER
	    VOLATILE;
    SQL
  end

  def memberfacthelperquery

    sql = <<-SQL
      create view memberfacthelperquery as
        select
          changeid
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
        from 
          memberfact

        UNION ALL

        select
          changeid
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
      from
        memberfact
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
      )
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
    transactionsource_sql.sub("transactionsource", "transactionsourceprev")
  end
  
  def transactionsourceprev
    db.ex(transactionsourceprev_sql)
  end
  
  def inserttransactionfact_sql
    <<-SQL
      CREATE OR REPLACE FUNCTION inserttransactionfact() RETURNS void 
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
          , current_timestamp 
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
          , current_timestamp
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
  
  
end
