require './lib/query/query'

class QuerySitesAtDate < Query
  def initialize(churn_db, header1, date, filter_terms)
    super(churn_db)
    @source = churn_db.fact_table
    @header1 = header1
    @date = date
    @filter_terms = filter_terms
  end

  def query_string
    filter = @filter_terms
    db = @churn_db.db

    sql = <<-EOS
	with last_change as
	(
		-- get the last change prior to the sample date for each member
		-- this tell us the state of each member at the sample date
		select
			max(changeid) changeid
		from
			#{db.quote_db(@source)}
		where
			changedate <= #{db.sql_date(@date)}
		group by 
			memberid
	)

	, selections as
	(
		-- finds all changes matching user criteria
		select 
			* 
		from
			#{db.quote_db(@source)}
		where
			net = 1
			and changeid in (select changeid from last_change)
			
			and (#{filter['status'].empty?}  or coalesce(status,'') = any (#{db.sql_array(filter['status'], 'varchar')})  or (coalesce(status,'') = '' and 'unassigned' = any (#{db.sql_array(filter['status'], 'varchar')})))
			and (#{filter['branchid'].empty?}  or coalesce(branchid,'') = any (#{db.sql_array(filter['branchid'], 'varchar')}) or (coalesce(branchid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['branchid'], 'varchar')})))
			and (#{filter['companyid'].empty?}  or coalesce(companyid,'') = any (#{db.sql_array(filter['companyid'], 'varchar')})  or (coalesce(companyid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['companyid'], 'varchar')})))
			and (#{filter['org'].empty?}  or coalesce(org,'') = any (#{db.sql_array(filter['org'], 'varchar')})  or (coalesce(org,'') = '' and 'unassigned' = any (#{db.sql_array(filter['org'], 'varchar')})) )
			and (#{filter['areaid'].empty?}  or coalesce(areaid,'') = any (#{db.sql_array(filter['areaid'], 'varchar')})  or (coalesce(areaid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['areaid'], 'varchar')})))
			and (#{filter['lead'].empty?}  or coalesce(lead,'') = any (#{db.sql_array(filter['lead'], 'varchar')})  or (coalesce(lead,'') = '' and 'unassigned' = any (#{db.sql_array(filter['lead'], 'varchar')})))
			and (#{filter['nuwelectorate'].empty?}  or coalesce(nuwelectorate,'') = any (#{db.sql_array(filter['nuwelectorate'], 'varchar')})  or (coalesce(nuwelectorate,'') = '' and 'unassigned' = any (#{db.sql_array(filter['nuwelectorate'], 'varchar')})))
			and (#{filter['state'].empty?}  or coalesce(state,'') = any (#{db.sql_array(filter['state'], 'varchar')})  or (coalesce(state,'') = '' and 'unassigned' = any (#{db.sql_array(filter['state'], 'varchar')})))
			and (#{filter['industryid'].empty?}  or coalesce(industryid,0)::varchar(5) = any (#{db.sql_array(filter['industryid'], 'varchar')})  or (coalesce(industryid,0) = 0 and 'unassigned' = any (#{db.sql_array(filter['industryid'], 'varchar')})))
			and (#{filter['del'].empty?}  or coalesce(del,0)::varchar(5) = any (#{db.sql_array(filter['del'], 'varchar')})  or (coalesce(del,0) = 0 and 'unassigned' = any (#{db.sql_array(filter['del'], 'varchar')})))
			and (#{filter['hsr'].empty?}  or coalesce(hsr,0)::varchar(5) = any (#{db.sql_array(filter['hsr'], 'varchar')})  or (coalesce(hsr,0) = 0 and 'unassigned' = any (#{db.sql_array(filter['hsr'], 'varchar')})))
			and (#{filter['feegroup'].empty?}  or coalesce(feegroupid,'') = any (#{db.sql_array(filter['feegroup'], 'varchar')})  or (coalesce(feegroupid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['feegroup'], 'varchar')})))
			
			and (#{filter['not_branchid'].empty?} or (not coalesce(branchid, '') = any (#{db.sql_array(filter['not_branchid'], 'varchar')}) or (coalesce(branchid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_branchid'], 'varchar')}))))
			and (#{filter['not_companyid'].empty?} or (not coalesce(companyid, '') = any (#{db.sql_array(filter['not_companyid'], 'varchar')}) or (coalesce(companyid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_companyid'], 'varchar')}))))
			and (#{filter['not_org'].empty?} or (not coalesce(org, '') = any (#{db.sql_array(filter['not_org'], 'varchar')}) or (coalesce(org, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_org'], 'varchar')}))))
			and (#{filter['not_areaid'].empty?} or (not coalesce(areaid, '') = any (#{db.sql_array(filter['not_areaid'], 'varchar')}) or (coalesce(areaid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_areaid'], 'varchar')}))))
			and (#{filter['not_lead'].empty?} or (not coalesce(lead, '') = any (#{db.sql_array(filter['not_lead'], 'varchar')}) or (coalesce(lead, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_lead'], 'varchar')}))))
			and (#{filter['not_nuwelectorate'].empty?} or (not coalesce(nuwelectorate, '') = any (#{db.sql_array(filter['not_nuwelectorate'], 'varchar')}) or (coalesce(nuwelectorate, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_nuwelectorate'], 'varchar')}))))
			and (#{filter['not_state'].empty?} or (not coalesce(state, '') = any (#{db.sql_array(filter['not_state'], 'varchar')}) or (coalesce(state, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_state'], 'varchar')}))))
			and (#{filter['not_industryid'].empty?} or (not coalesce(industryid, 0)::varchar(5) = any (#{db.sql_array(filter['not_industryid'], 'varchar')}) or (coalesce(industryid, 0)  = 0 and not 'unassigned' = any (#{db.sql_array(filter['not_industryid'], 'varchar')}))))
			and (#{filter['not_del'].empty?} or (not coalesce(del, 0)::varchar(5) = any (#{db.sql_array(filter['not_del'], 'varchar')}) or (coalesce(del, 0)  = 0 and not 'unassigned' = any (#{db.sql_array(filter['not_del'], 'varchar')}))))
			and (#{filter['not_hsr'].empty?} or (not coalesce(hsr, 0)::varchar(5) = any (#{db.sql_array(filter['not_hsr'], 'varchar')}) or (coalesce(hsr, 0)  = 0 and not 'unassigned' = any (#{db.sql_array(filter['not_hsr'], 'varchar')}))))
			and (#{filter['not_feegroup'].empty?} or (not coalesce(feegroupid, '') = any (#{db.sql_array(filter['not_feegroup'], 'varchar')}) or (coalesce(feegroupid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_feegroup'], 'varchar')}))))
			
			and (#{filter['statusstaffid'].empty?}  or coalesce(statusstaffid,'') = any (#{db.sql_array(filter['statusstaffid'], 'varchar')})  or (coalesce(statusstaffid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['statusstaffid'], 'varchar')})))
			and (#{filter['supportstaffid'].empty?}  or coalesce(supportstaffid,'') = any (#{db.sql_array(filter['supportstaffid'], 'varchar')})  or (coalesce(supportstaffid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['supportstaffid'], 'varchar')})))
			and (#{filter['employerid'].empty?}  or coalesce(employerid,'') = any (#{db.sql_array(filter['employerid'], 'varchar')})  or (coalesce(employerid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['employerid'], 'varchar')})))
			and (#{filter['hostemployerid'].empty?}  or coalesce(hostemployerid,'') = any (#{db.sql_array(filter['hostemployerid'], 'varchar')})  or (coalesce(hostemployerid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['hostemployerid'], 'varchar')})))
			and (#{filter['employmenttypeid'].empty?}  or coalesce(employmenttypeid,'') = any (#{db.sql_array(filter['employmenttypeid'], 'varchar')})  or (coalesce(employmenttypeid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['employmenttypeid'], 'varchar')})))
			
			and (#{filter['not_statusstaffid'].empty?} or (not coalesce(statusstaffid, '') = any (#{db.sql_array(filter['not_statusstaffid'], 'varchar')}) or (coalesce(statusstaffid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_statusstaffid'], 'varchar')}))))
			and (#{filter['not_supportstaffid'].empty?} or (not coalesce(supportstaffid, '') = any (#{db.sql_array(filter['not_supportstaffid'], 'varchar')}) or (coalesce(supportstaffid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_supportstaffid'], 'varchar')}))))
			and (#{filter['not_employerid'].empty?} or (not coalesce(employerid, '') = any (#{db.sql_array(filter['not_employerid'], 'varchar')}) or (coalesce(employerid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_employerid'], 'varchar')}))))
			and (#{filter['not_hostemployerid'].empty?} or (not coalesce(hostemployerid, '') = any (#{db.sql_array(filter['not_hostemployerid'], 'varchar')}) or (coalesce(hostemployerid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_hostemployerid'], 'varchar')}))))
			and (#{filter['not_employmenttypeid'].empty?} or (not coalesce(employmenttypeid, '') = any (#{db.sql_array(filter['not_employmenttypeid'], 'varchar')}) or (coalesce(employmenttypeid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_employmenttypeid'], 'varchar')}))))
			
			and (#{filter['paymenttypeid'].empty?} or coalesce(paymenttypeid,'') = any (#{db.sql_array(filter['paymenttypeid'], 'varchar')})  or (coalesce(paymenttypeid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['paymenttypeid'], 'varchar')})))
			and (#{filter['not_paymenttypeid'].empty?} or (not coalesce(paymenttypeid, '') = any (#{db.sql_array(filter['not_paymenttypeid'], 'varchar')}) or (coalesce(paymenttypeid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_paymenttypeid'], 'varchar')}))))
 	)
	select distinct companyid from selections;

EOS

    sql
  end
end
