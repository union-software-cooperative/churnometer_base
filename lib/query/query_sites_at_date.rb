class QuerySitesAtDate
  def initialize(source, header1, header2, dte, with_trans, selection, companyid)
    @source = source
    @header1 = header1
    @header2 = header2
    @dte = dte
    @with_trans = with_trans
    @selection = selection
    @companyid = companyid
  end

protected
  def query_string
    raise 'tbd'

    status_list = []
    branchid_list = []
    companyid_list = []
    org_list = []
    areaid_list = []
    lead_list = []
    nuwelectorate_list = []
    state_list = []
    industryid_list = []
    del_list = []
    hsr_list = []
    feegroup_list = []
    supportstaffid_list = []
    statusstaffid_list = []
    employerid_list = []
    hostemployerid_list = []
    employmenttypeid_list = []
    paymenttypeid_list = []

    status_list_empty = false
    branchid_list_empty = false
    companyid_list_empty = false
    org_list_empty = false
    areaid_list_empty = false
    lead_list_empty = false
    nuwelectorate_list_empty = false
    state_list_empty = false
    industryid_list_empty = false
    del_list_empty = false
    hsr_list_empty = false
    feegroup_list_empty = false
    supportstaffid_list_empty = false
    statusstaffid_list_empty = false
    employerid_list_empty = false
    hostemployerid_list_empty = false
    employmenttypeid_list_empty = false
    paymenttypeid_list_empty = false
    
    not_status_list = []
    not_branchid_list = []
    not_companyid_list = []
    not_org_list = []
    not_areaid_list = []
    not_lead_list = []
    not_nuwelectorate_list = []
    not_state_list = []
    not_industryid_list = []
    not_del_list = []
    not_hsr_list = []
    not_feegroup_list = []
    not_supportstaffid_list = []
    not_statusstaffid_list = []
    not_employerid_list = []
    not_hostemployerid_list = []
    not_employmenttypeid_list = []
    not_paymenttypeid_list = []
    
    not_status_list_empty = false
    not_branchid_list_empty = false
    not_companyid_list_empty = false
    not_org_list_empty = false
    not_areaid_list_empty = false
    not_lead_list_empty = false
    not_nuwelectorate_list_empty = false
    not_state_list_empty = false
    not_industryid_list_empty = false
    not_del_list_empty = false
    not_hsr_list_empty = false
    not_feegroup_list_empty = false
    not_supportstaffid_list_empty = false
    not_statusstaffid_list_empty = false
    not_employerid_list_empty = false
    not_hostemployerid_list_empty = false
    not_employmenttypeid_list_empty = false
    not_paymenttypeid_list_empty = false

    xml = REXML::Document.new(@selection)
    
    status_list = xml_array_to_array('/search/status', xml)
    branchid_list = xml_array_to_array('/search/branchid', xml)
    companyid_list = xml_array_to_array('/search/companyid', xml)
    org_list = xml_array_to_array('/search/org', xml)
    areaid_list = xml_array_to_array('/search/areaid', xml)
    lead_list = xml_array_to_array('/search/lead', xml)
    nuwelectorate_list = xml_array_to_array('/search/nuwelectorate', xml)
    state_list = xml_array_to_array('/search/state', xml) 
    industryid_list = xml_array_to_array('/search/industryid', xml)
    del_list = xml_array_to_array('/search/del', xml)
    hsr_list = xml_array_to_array('/search/hsr', xml)
    feegroup_list = xml_array_to_array('/search/feegroup', xml)
    supportstaffid_list = xml_array_to_array('/search/supportstaffid', xml)
    statusstaffid_list = xml_array_to_array('/search/statusstaffid', xml)
    employerid_list = xml_array_to_array('/search/employerid', xml)
    hostemployerid_list = xml_array_to_array('/search/hostemployerid', xml)
    employmenttypeid_list = xml_array_to_array('/search/employmenttypeid', xml)
    paymenttypeid_list = xml_array_to_array('/search/paymenttypeid', xml)
    
    not_status_list = xml_array_to_array('/search/not_status', xml)
    not_branchid_list = xml_array_to_array('/search/not_branchid', xml)
    not_companyid_list = xml_array_to_array('/search/not_companyid', xml)
    not_org_list = xml_array_to_array('/search/not_org', xml)
    not_areaid_list = xml_array_to_array('/search/not_areaid', xml)
    not_lead_list = xml_array_to_array('/search/not_lead', xml)
    not_nuwelectorate_list = xml_array_to_array('/search/not_nuwelectorate', xml)
    not_state_list = xml_array_to_array('/search/not_state', xml)
    not_industryid_list = xml_array_to_array('/search/not_industryid', xml)
    not_del_list = xml_array_to_array('/search/not_del', xml)
    not_hsr_list = xml_array_to_array('/search/not_hsr', xml)
    not_feegroup_list = xml_array_to_array('/search/not_feegroup', xml)
    not_supportstaffid_list = xml_array_to_array('/search/not_supportstaffid', xml)
    not_statusstaffid_list = xml_array_to_array('/search/not_statusstaffid', xml)
    not_employerid_list = xml_array_to_array('/search/not_employerid', xml)
    not_hostemployerid_list = xml_array_to_array('/search/not_hostemployerid', xml)
    not_employmenttypeid_list = xml_array_to_array('/search/not_employmenttypeid', xml)
    not_paymenttypeid_list = xml_array_to_array('/search/not_paymenttypeid', xml)

    sql = <<-EOS
'
	with last_change as
	(
		-- get the last change prior to the sample date for each member
		-- this tell us the state of each member at the sample date
		select
			max(changeid) changeid
		from
			' || source || '
		where
			changedate <= $2
		group by 
			memberid
	)

	, selections as
	(
		-- finds all changes matching user criteria
		select 
			* 
		from
			' || source || ' 
		where
			net = 1
			and changeid in (select changeid from last_change)
			
			and ($4 /* status_list_empty */ or coalesce(status,'''') = any ($3 /* status_list  */)  or (coalesce(status,'''') = '''' and ''unassigned'' = any ($3)))
			and ($6 /* branchid_list_empty */ or coalesce(branchid,'''') = any ($5 /* branchid_list  */) or (coalesce(branchid,'''') = '''' and ''unassigned'' = any ($5)))
			and ($8 /* companyid_list_empty */ or coalesce(companyid,'''') = any ($7 /* companyid_list  */)  or (coalesce(companyid,'''') = '''' and ''unassigned'' = any ($7)))
			and ($10 /* org_list_empty */ or coalesce(org,'''') = any ($9 /* org_list  */)  or (coalesce(org,'''') = '''' and ''unassigned'' = any ($9)) )
			and ($12 /* areaid_list_empty */ or coalesce(areaid,'''') = any ($11 /* areaid_list  */)  or (coalesce(areaid,'''') = '''' and ''unassigned'' = any ($11)))
			and ($14 /* lead_list_empty */ or coalesce(lead,'''') = any ($13 /* lead_list  */)  or (coalesce(lead,'''') = '''' and ''unassigned'' = any ($13)))
			and ($16 /* nuwelectorate_list_empty */ or coalesce(nuwelectorate,'''') = any ($15 /* nuwelectorate_list  */)  or (coalesce(nuwelectorate,'''') = '''' and ''unassigned'' = any ($15)))
			and ($18 /* state_list_empty */ or coalesce(state,'''') = any ($17 /* state_list  */)  or (coalesce(state,'''') = '''' and ''unassigned'' = any ($17)))
			and ($20 /* industryid_list_empty */ or coalesce(industryid,0)::varchar(5) = any ($19 /* industryid_list  */)  or (coalesce(industryid,0) = 0 and ''unassigned'' = any ($19)))
			and ($22 /* del_list_empty */ or coalesce(del,0)::varchar(5) = any ($21 /* del_list  */)  or (coalesce(del,0) = 0 and ''unassigned'' = any ($21)))
			and ($24 /* hsr_list_empty */ or coalesce(hsr,0)::varchar(5) = any ($23 /* hsr_list  */)  or (coalesce(hsr,0) = 0 and ''unassigned'' = any ($23)))
			and ($26 /* feegroup_list_empty */ or coalesce(feegroupid,'''') = any ($25 /* feegroup_list  */)  or (coalesce(feegroupid,'''') = '''' and ''unassigned'' = any ($25)))
			
			and ($30 or (not coalesce(branchid, '''') = any ($29) or (coalesce(branchid, '''')  = '''' and not ''unassigned'' = any ($29))))
			and ($32 or (not coalesce(companyid, '''') = any ($31) or (coalesce(companyid, '''')  = '''' and not ''unassigned'' = any ($31))))
			and ($34 or (not coalesce(org, '''') = any ($33) or (coalesce(org, '''')  = '''' and not ''unassigned'' = any ($33))))
			and ($36 or (not coalesce(areaid, '''') = any ($35) or (coalesce(areaid, '''')  = '''' and not ''unassigned'' = any ($35))))
			and ($38 or (not coalesce(lead, '''') = any ($37) or (coalesce(lead, '''')  = '''' and not ''unassigned'' = any ($37))))
			and ($40 or (not coalesce(nuwelectorate, '''') = any ($39) or (coalesce(nuwelectorate, '''')  = '''' and not ''unassigned'' = any ($39))))
			and ($42 or (not coalesce(state, '''') = any ($41) or (coalesce(state, '''')  = '''' and not ''unassigned'' = any ($41))))
			and ($44 or (not coalesce(industryid, 0)::varchar(5) = any ($43) or (coalesce(industryid, 0)  = 0 and not ''unassigned'' = any ($43))))
			and ($46 or (not coalesce(del, 0)::varchar(5) = any ($45) or (coalesce(del, 0)  = 0 and not ''unassigned'' = any ($45))))
			and ($48 or (not coalesce(hsr, 0)::varchar(5) = any ($47) or (coalesce(hsr, 0)  = 0 and not ''unassigned'' = any ($47))))
			and ($50 or (not coalesce(feegroupid, '''') = any ($49) or (coalesce(feegroupid, '''')  = '''' and not ''unassigned'' = any ($49))))
			
			and ($52 /* statusstaffid_list_empty */ or coalesce(statusstaffid,'''') = any ($51 /* statusstaffid_list  */)  or (coalesce(statusstaffid,'''') = '''' and ''unassigned'' = any ($51)))
			and ($54 /* supportstaffid_list_empty */ or coalesce(supportstaffid,'''') = any ($53 /* supportstaffid_list  */)  or (coalesce(supportstaffid,'''') = '''' and ''unassigned'' = any ($53)))
			and ($56 /* employerid_list_empty */ or coalesce(employerid,'''') = any ($55 /* employerid_list  */)  or (coalesce(employerid,'''') = '''' and ''unassigned'' = any ($55)))
			and ($58 /* hostemployerid_list_empty */ or coalesce(hostemployerid,'''') = any ($57 /* hostemployerid_list  */)  or (coalesce(hostemployerid,'''') = '''' and ''unassigned'' = any ($57)))
			and ($60 /* employmenttypeid_list_empty */ or coalesce(employmenttypeid,'''') = any ($59 /* employmenttypeid_list  */)  or (coalesce(employmenttypeid,'''') = '''' and ''unassigned'' = any ($59)))
			
			and ($62 or (not coalesce(statusstaffid, '''') = any ($61) or (coalesce(statusstaffid, '''')  = '''' and not ''unassigned'' = any ($61))))
			and ($64 or (not coalesce(supportstaffid, '''') = any ($63) or (coalesce(supportstaffid, '''')  = '''' and not ''unassigned'' = any ($63))))
			and ($66 or (not coalesce(employerid, '''') = any ($65) or (coalesce(employerid, '''')  = '''' and not ''unassigned'' = any ($65))))
			and ($68 or (not coalesce(hostemployerid, '''') = any ($67) or (coalesce(hostemployerid, '''')  = '''' and not ''unassigned'' = any ($67))))
			and ($70 or (not coalesce(employmenttypeid, '''') = any ($69) or (coalesce(employmenttypeid, '''')  = '''' and not ''unassigned'' = any ($69))))
			
			and ($72 /* paymenttypeid_list_empty */ or coalesce(paymenttypeid,'''') = any ($71 /* paymenttypeid_list  */)  or (coalesce(paymenttypeid,'''') = '''' and ''unassigned'' = any ($71)))
			and ($74 or (not coalesce(paymenttypeid, '''') = any ($73) or (coalesce(paymenttypeid, '''')  = '''' and not ''unassigned'' = any ($73))))
 	)
'
'
	select distinct companyid from selections;
';
EOS

    return @db.ex(sql)
  end
end
