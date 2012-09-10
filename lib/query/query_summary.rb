require './lib/query/query_filter'
require './lib/query/query_sites_at_date'
require './lib/settings'
require 'nokogiri'

class QuerySummary < QueryFilter
  def initialize(churn_db, header1, start_date, end_date, with_trans, site_constraint, filter_xml)
    super(churn_db)
    @source = churn_db.fact_table
    @header1 = header1
    @start_date = start_date
    @end_date = end_date
    @with_trans = with_trans
    @site_constraint = site_constraint
    @filter_xml = filter_xml
  end

  def query_string
#CREATE OR REPLACE FUNCTION summary(IN @source text, IN @header1 text, IN header2 text, IN start_date timestamp without time zone, IN end_date timestamp without time zone, IN with_trans boolean, IN site_constrain text, IN selection xml, OUT row_header1 character varying, OUT row_header1_id character varying, OUT start_count integer, OUT a1p_start_count integer, OUT a1p_real_gain integer, OUT a1p_unchanged_gain integer, OUT a1p_newjoin integer, OUT a1p_rejoin integer, OUT a1p_real_loss integer, OUT a1p_to_paying integer, OUT a1p_to_other integer, OUT a1p_other_gain integer, OUT a1p_other_loss integer, OUT a1p_end_count integer, OUT paying_start_count integer, OUT paying_real_gain integer, OUT paying_real_loss integer, OUT paying_real_net integer, OUT paying_other_gain integer, OUT paying_other_loss integer, OUT paying_end_count integer, OUT stopped_start_count integer, OUT stopped_real_gain integer, OUT stopped_unchanged_gain integer, OUT rule59_unchanged_gain integer, OUT stopped_real_loss integer, OUT stopped_to_paying integer, OUT stopped_to_other integer, OUT stopped_real_net integer, OUT stopped_other_gain integer, OUT stopped_other_loss integer, OUT stopped_end_count integer, OUT other_gain integer, OUT other_loss integer, OUT external_gain integer, OUT external_loss integer, OUT net integer, OUT end_count integer, OUT cross_check integer, OUT posted numeric, OUT unposted numeric, OUT income_net numeric, OUT contributors integer, OUT transactions integer, OUT annualisedavgcontribution numeric, OUT lateness text, OUT payrollcontactdetail text, OUT paidto date, OUT paymenttype text)
    xml = Nokogiri::XML(@filter_xml)
    
    dte = Time.at(0)

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

  types = Hash.new('varchar')
  #types[:branchid_list] = 'varchar'
  #types[:not_branchid_list] = 'varchar'

if @site_constraint.empty?
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

else
	# return the results for sites found at either the end of the beginning of this selection
	# this is a way of ruling out the effect of transfers, to determine what the targets should be
	# for sites as currently held (end_date) or held at the start (start_date)
	dte = 
    if @site_constraint == 'start'
      @start_date
    else
      @end_date
    end

	# override the filter to be sites as at the start or end
	# dbeswick: test
  #site_xml:= (select xmlelement(NAME search, xmlagg(xmlforest(companyid as  "companyid" ))) from sites_at_date( @source, @header1, header2, dte, with_trans, selection ));
  company_id_list = QuerySitesAtDate.new(@source, @header1, header2, dte, @with_trans, xml_filter).execute.collect { |record| record['companyid'] }
	#companyid_list:=xml_array_to_array(xpath('/search/companyid', site_xml));
	
	# keep original status filter
	status_list = xml_array_to_array('/search/status', xml)
end

sql = <<-EOS
	with nonstatusselections as
	(
		-- finds all changes matching user criteria
		select 
			* 
		from
			#{@source} 
		where
			changedate <= #{sql_datetime(@end_date)} -- we need to count every value since Churnobyls start to determine start_count.  But everything after enddate can be ignored.
  		and (#{branchid_list.empty?} or coalesce(branchid,'') = any (#{sql_array(branchid_list, types[:branchid_list])}) or (coalesce(branchid,'') = '' and 'unassigned' = any (#{sql_array(branchid_list, types[:branchid_list])})))
			and (#{companyid_list.empty?} or coalesce(companyid,'') = any (#{sql_array(companyid_list, types[:companyid_list])})  or (coalesce(companyid,'') = '' and 'unassigned' = any (#{sql_array(companyid_list, types[:companyid_list])})))
			and (#{org_list.empty?} or coalesce(org,'') = any (#{sql_array(org_list, types[:org_list])})  or (coalesce(org,'') = '' and 'unassigned' = any (#{sql_array(org_list, types[:org_list])})) )
			and (#{areaid_list.empty?} or coalesce(areaid,'') = any (#{sql_array(areaid_list, types[:areaid_list])})  or (coalesce(areaid,'') = '' and 'unassigned' = any (#{sql_array(areaid_list, types[:areaid_list])})))
			and (#{lead_list.empty?} or coalesce(lead,'') = any (#{sql_array(lead_list, types[:lead_list])})  or (coalesce(lead,'') = '' and 'unassigned' = any (#{sql_array(lead_list, types[:lead_list])})))
			and (#{nuwelectorate_list.empty?} or coalesce(nuwelectorate,'') = any (#{sql_array(nuwelectorate_list, types[:nuwelectorate_list])})  or (coalesce(nuwelectorate,'') = '' and 'unassigned' = any (#{sql_array(nuwelectorate_list, types[:nuwelectorate_list])})))
			and (#{state_list.empty?} or coalesce(state,'') = any (#{sql_array(state_list, types[:state_list])})  or (coalesce(state,'') = '' and 'unassigned' = any (#{sql_array(state_list, types[:state_list])})))
			and (#{industryid_list.empty?} or coalesce(industryid,0)::varchar(5) = any (#{sql_array(industryid_list, types[:industryid_list])})  or (coalesce(industryid,0) = 0 and 'unassigned' = any (#{sql_array(industryid_list, types[:industryid_list])})))
			and (#{del_list.empty?} or coalesce(del,0)::varchar(5) = any (#{sql_array(del_list, types[:del_list])})  or (coalesce(del,0) = 0 and 'unassigned' = any (#{sql_array(del_list, types[:del_list])})))
			and (#{hsr_list.empty?} or coalesce(hsr,0)::varchar(5) = any (#{sql_array(hsr_list, types[:hsr_list])})  or (coalesce(hsr,0) = 0 and 'unassigned' = any (#{sql_array(hsr_list, types[:hsr_list])})))
			and (#{feegroup_list.empty?} or coalesce(feegroupid,'') = any (#{sql_array(feegroup_list, types[:feegroup_list])})  or (coalesce(feegroupid,'') = '' and 'unassigned' = any (#{sql_array(feegroup_list, types[:feegroup_list])})))
			
			and (#{not_branchid_list.empty?} or (not coalesce(branchid, '') = any (#{sql_array(not_branchid_list, types[:not_branchid_list])}) or (coalesce(branchid, '')  = '' and not 'unassigned' = any (#{sql_array(not_branchid_list, types[:not_branchid_list])}))))
			and (#{not_companyid_list.empty?} or (not coalesce(companyid, '') = any (#{sql_array(not_companyid_list, types[:not_companyid_list])}) or (coalesce(companyid, '')  = '' and not 'unassigned' = any (#{sql_array(not_companyid_list, types[:not_companyid_list])}))))
			and (#{not_org_list.empty?} or (not coalesce(org, '') = any (#{sql_array(not_org_list, types[:not_org_list])}) or (coalesce(org, '')  = '' and not 'unassigned' = any (#{sql_array(not_org_list, types[:not_org_list])}))))
			and (#{not_areaid_list.empty?} or (not coalesce(areaid, '') = any (#{sql_array(not_areaid_list, types[:not_areaid_list])}) or (coalesce(areaid, '')  = '' and not 'unassigned' = any (#{sql_array(not_areaid_list, types[:not_areaid_list])}))))
			and (#{not_lead_list.empty?} or (not coalesce(lead, '') = any (#{sql_array(not_lead_list, types[:not_lead_list])}) or (coalesce(lead, '')  = '' and not 'unassigned' = any (#{sql_array(not_lead_list, types[:not_lead_list])}))))
			and (#{not_nuwelectorate_list.empty?} or (not coalesce(nuwelectorate, '') = any (#{sql_array(not_nuwelectorate_list, types[:not_nuwelectorate_list])}) or (coalesce(nuwelectorate, '')  = '' and not 'unassigned' = any (#{sql_array(not_nuwelectorate_list, types[:not_nuwelectorate_list])}))))
			and (#{not_state_list.empty?} or (not coalesce(state, '') = any (#{sql_array(not_state_list, types[:not_state_list])}) or (coalesce(state, '')  = '' and not 'unassigned' = any (#{sql_array(not_state_list, types[:not_state_list])}))))
			and (#{not_industryid_list.empty?} or (not coalesce(industryid, 0)::varchar(5) = any (#{sql_array(not_industryid_list, types[:not_industryid_list])}) or (coalesce(industryid, 0)  = 0 and not 'unassigned' = any (#{sql_array(not_industryid_list, types[:not_industryid_list])}))))
			and (#{not_del_list.empty?} or (not coalesce(del, 0)::varchar(5) = any (#{sql_array(not_del_list, types[:not_del_list])}) or (coalesce(del, 0)  = 0 and not 'unassigned' = any (#{sql_array(not_del_list, types[:not_del_list])}))))
			and (#{not_hsr_list.empty?} or (not coalesce(hsr, 0)::varchar(5) = any (#{sql_array(not_hsr_list, types[:not_hsr_list])}) or (coalesce(hsr, 0)  = 0 and not 'unassigned' = any (#{sql_array(not_hsr_list, types[:not_hsr_list])}))))
			and (#{not_feegroup_list.empty?} or (not coalesce(feegroupid, '') = any (#{sql_array(not_feegroup_list, types[:not_feegroup_list])}) or (coalesce(feegroupid, '')  = '' and not 'unassigned' = any (#{sql_array(not_feegroup_list, types[:not_feegroup_list])}))))
	

			and (#{supportstaffid_list.empty?} or coalesce(supportstaffid,'') = any (#{sql_array(supportstaffid_list, types[:supportstaffid_list])})  or (coalesce(supportstaffid,'') = '' and 'unassigned' = any (#{sql_array(supportstaffid_list, types[:supportstaffid_list])})))
			and (#{employerid_list.empty?} or coalesce(employerid,'') = any (#{sql_array(employerid_list, types[:employerid_list])})  or (coalesce(employerid,'') = '' and 'unassigned' = any (#{sql_array(employerid_list, types[:employerid_list])})))
			and (#{hostemployerid_list.empty?} or coalesce(hostemployerid,'') = any (#{sql_array(hostemployerid_list, types[:hostemployerid_list])})  or (coalesce(hostemployerid,'') = '' and 'unassigned' = any (#{sql_array(hostemployerid_list, types[:hostemployerid_list])})))
			and (#{employmenttypeid_list.empty?} or coalesce(employmenttypeid,'') = any (#{sql_array(employmenttypeid_list, types[:employmenttypeid_list])})  or (coalesce(employmenttypeid,'') = '' and 'unassigned' = any (#{sql_array(employmenttypeid_list, types[:employmenttypeid_list])})))
			
			and (#{not_supportstaffid_list.empty?} or (not coalesce(supportstaffid, '') = any (#{sql_array(not_supportstaffid_list, types[:not_supportstaffid_list])}) or (coalesce(supportstaffid, '')  = '' and not 'unassigned' = any (#{sql_array(not_supportstaffid_list, types[:not_supportstaffid_list])}))))
			and (#{not_employerid_list.empty?} or (not coalesce(employerid, '') = any (#{sql_array(not_employerid_list, types[:not_employerid_list])}) or (coalesce(employerid, '')  = '' and not 'unassigned' = any (#{sql_array(not_employerid_list, types[:not_employerid_list])}))))
			and (#{not_hostemployerid_list.empty?} or (not coalesce(hostemployerid, '') = any (#{sql_array(not_hostemployerid_list, types[:not_hostemployerid_list])}) or (coalesce(hostemployerid, '')  = '' and not 'unassigned' = any (#{sql_array(not_hostemployerid_list, types[:not_hostemployerid_list])}))))
			and (#{not_employmenttypeid_list.empty?} or (not coalesce(employmenttypeid, '') = any (#{sql_array(not_employmenttypeid_list, types[:not_employmenttypeid_list])}) or (coalesce(employmenttypeid, '')  = '' and not 'unassigned' = any (#{sql_array(not_employmenttypeid_list, types[:not_employmenttypeid_list])}))))
			
			and (#{paymenttypeid_list.empty?} or coalesce(paymenttypeid,'') = any (#{sql_array(paymenttypeid_list, types[:paymenttypeid_list])})  or (coalesce(paymenttypeid,'') = '' and 'unassigned' = any (#{sql_array(paymenttypeid_list, types[:paymenttypeid_list])})))
			
			and (#{not_paymenttypeid_list.empty?} or (not coalesce(paymenttypeid, '') = any (#{sql_array(not_paymenttypeid_list, types[:not_paymenttypeid_list])}) or (coalesce(paymenttypeid, '')  = '' and not 'unassigned' = any (#{sql_array(not_paymenttypeid_list, types[:not_paymenttypeid_list])}))))
			
	)
	, userselections as 
	(
		select
			*
		from
			nonstatusselections
		where
			(#{status_list.empty?} or coalesce(status,'') = any (#{sql_array(status_list, types[:status_list])})  or (coalesce(status,'') = '' and 'unassigned' = any (#{sql_array(status_list, types[:status_list])})))
			and (#{statusstaffid_list.empty?} or coalesce(statusstaffid,'') = any (#{sql_array(statusstaffid_list, types[:statusstaffid_list])})  or (coalesce(statusstaffid,'') = '' and 'unassigned' = any (#{sql_array(statusstaffid_list, types[:statusstaffid_list])})))
			and (#{not_statusstaffid_list.empty?} or (not coalesce(statusstaffid, '') = any (#{sql_array(not_statusstaffid_list, types[:not_statusstaffid_list])}) or (coalesce(statusstaffid, '')  = '' and not 'unassigned' = any (#{sql_array(not_statusstaffid_list, types[:not_statusstaffid_list])}))))
	)
	, nonegations as
	(
		-- removes changes that make no difference to the results or represent gains and losses that cancel out
		select
			*, case when u1.changeid in (select changeid from userselections u group by changeid having sum(u.net) <> 0) then false else true end internalTransfer
		from 
			userselections u1
		where
			u1.changeid in (select changeid from userselections u group by changeid having sum(u.net) <> 0) -- any change who has only side in the user selection 
			or u1.changeid in (select changeid from userselections u where payinggain <> 0 or payingloss <> 0 ) -- both sides (if in user selection) if one side is paying and there was a paying change 
 			or u1.changeid in (select changeid from userselections u where a1pgain <> 0 or a1ploss <> 0) -- both sides (if in user selection) if one side is paying and there was a paying change 
 			or u1.#{@header1}delta <> 0 -- unless the changes that cancel out but are transfers between grouped items
 	)
, trans as
(
	select 
EOS

sql <<
	if @header1 == 'statusstaffid'
	   "case when coalesce(t.staffid::varchar(200),'') = '' then 'unassigned' else t.staffid::varchar(200) end row_header1"
	else
		"case when coalesce(u1.#{@header1}::varchar(200),'') = '' then 'unassigned' else u1.#{@header1}::varchar(200) end row_header1"
	end

sql << <<-EOS
		, sum(case when amount::numeric > 0.0 then amount::numeric else 0.0 end) posted
		, sum(case when amount::numeric < 0.0 then amount::numeric else 0.0 end) undone
		, sum(amount::numeric) income_net
		, count(distinct t.memberid) contributors
		, sum(amount::numeric) / count(distinct t.memberid) avgContribution
		, ( sum(amount::numeric) / count(distinct t.memberid)::numeric ) / (#{sql_datetime(@end_date)}::date - #{sql_datetime(@start_date)}::date) * 365::numeric annualizedAvgContribution
		, count(*) transactions
	from
		transactionfact t
		inner join nonstatusselections u1 on
			u1.net = 1
			and u1.changeid = t.changeid
	where
		t.creationdate > #{sql_datetime(@start_date)}
		and t.creationdate <= #{sql_datetime(@end_date)}
		-- statusstaffid is special.  Rather than members and their transactions being assigned to an organising area
		-- statusstaffid is about who actually changed a status or who actually posted the transaction.
		-- for this reason, we filter status staff on staffid field in transactionfact.  
		and (#{statusstaffid_list.empty?} or coalesce(staffid,'') = any (#{sql_array(statusstaffid_list, types[:statusstaffid_list])})  or (coalesce(staffid,'') = '' and 'unassigned' = any (#{sql_array(statusstaffid_list, types[:statusstaffid_list])})))
		and (#{not_statusstaffid_list.empty?} or (not coalesce(staffid, '') = any (#{sql_array(not_statusstaffid_list, types[:not_statusstaffid_list])}) or (coalesce(staffid, '')  = '' and not 'unassigned' = any (#{sql_array(not_statusstaffid_list, types[:not_statusstaffid_list])}))))
	group by 
EOS

sql <<
	if @header1 == 'statusstaffid' 
	   "case when coalesce(t.staffid::varchar(200),'') = '' then 'unassigned' else t.staffid::varchar(200) end"
	else
		"case when coalesce(u1.#{@header1}::varchar(200),'') = '' then 'unassigned' else u1.#{@header1}::varchar(200) end"
	end

sql << <<-EOS

)
	, counts as
	(
		-- sum changes, if status doesnt change, then the change is a transfer
		select 
			case when coalesce(#{@header1}::varchar(200),'') = '' then 'unassigned' else #{@header1}::varchar(200) end row_header1
			--, date_trunc('week', changedate)::date row_header2
			, sum(case when changedate <= #{sql_datetime(@start_date)} then net else 0 end) as start_count
			, sum(case when changedate <= #{sql_datetime(@start_date)} and status = '14' then net else 0 end) as a1p_start_count -- cant use a1pgain + a1ploss because they only count when a status changes, where as we want every a1p value in the selection, even if it is a transfer
			, sum(case when changedate <= #{sql_datetime(@start_date)} and status = '1' then net else 0 end) as paying_start_count
			, sum(case when changedate <= #{sql_datetime(@start_date)} and status = '11' then net else 0 end) as stopped_start_count
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then a1pgain else 0 end) a1p_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and _changeid is null then a1pgain else 0 end) a1p_unchanged_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and coalesce(_status, '') = '' then a1pgain else 0 end) a1p_newjoin
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and coalesce(_status, '') <>'' then a1pgain else 0 end) a1p_rejoin			
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then a1ploss else 0 end) a1p_loss
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and coalesce(_status,'') = '1' then a1ploss else 0 end) a1p_to_paying
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and coalesce(_status,'') <> '1' then a1ploss else 0 end) a1p_to_other			
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then payinggain else 0 end) paying_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then payingloss else 0 end) paying_loss

			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then stoppedgain else 0 end) stopped_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and _changeid is null then stoppedgain else 0 end) stopped_unchanged_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and _changeid is null and coalesce(_status,'') = '3' then loss else 0 end) rule59_unchanged_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then stoppedloss else 0 end) stopped_loss
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and coalesce(_status,'') = '1' then stoppedloss else 0 end) stopped_to_paying
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and coalesce(_status,'') <> '1' then stoppedloss else 0 end) stopped_to_other			
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and status = '14' then othergain else 0 end) a1p_other_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and status = '14' then otherloss else 0 end) a1p_other_loss
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and status = '1' then othergain else 0 end) paying_other_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and status = '1' then otherloss else 0 end) paying_other_loss
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and status = '11' then othergain else 0 end) stopped_other_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and status = '11' then otherloss else 0 end) stopped_other_loss
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and not (status = '1' or status = '14' or status = '11') then othergain else 0 end) other_other_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and not (status = '1' or status = '14' or status = '11') then otherloss else 0 end) other_other_loss
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then othergain else 0 end) other_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then otherloss else 0 end) other_loss
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and not internalTransfer then othergain else 0 end) external_gain
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} and not internalTransfer then otherloss else 0 end) external_loss
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then a1pgain+a1ploss else 0 end) a1p_net
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then payinggain+payingloss else 0 end) paying_net
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then stoppedgain+stoppedloss else 0 end) stopped_net
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then othergain+otherloss else 0 end) other_net
			, sum(case when changedate > #{sql_datetime(@start_date)} and changedate <= #{sql_datetime(@end_date)} then coalesce(c.net,0) else 0 end) net
			, sum(net) as end_count
			, sum(case when status = '14' then net else 0 end) as a1p_end_count -- cant use a1pgain + a1ploss because they only count when a status changes, where as we want every a1p value in the selection, even if it is a transfer
			, sum(case when status = '1' then net else 0 end) as paying_end_count
			, sum(case when status = '11' then net else 0 end) as stopped_end_count
			
		from 
			nonegations c
		group by 
			case when coalesce(#{@header1}::varchar(200),'') = '' then 'unassigned' else #{@header1}::varchar(200) end 
			--, date_trunc('week', changedate)::date
	)
	, withtrans as
	(
		select
			c.*
EOS

sql << 
  if @with_trans 
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

sql <<
<<-EOS
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
			, 0 a1p_gain
			, 0 a1p_unchanged_gain
			, 0 a1p_newjoin
			, 0 a1p_rejoin
			, 0 a1p_loss
			, 0 a1p_to_paying
			, 0 a1p_to_other
			, 0 paying_gain
			, 0 paying_loss
			, 0 stopped_gain
			, 0 stopped_unchanged_gain
			, 0 rule59_unchanged_gain
			, 0 stopped_loss
			, 0 stopped_to_paying
			, 0 stopped_to_other
			, 0 a1p_other_gain
			, 0 a1p_other_loss
			, 0 paying_other_gain
			, 0 paying_other_loss
			, 0 stopped_other_gain
			, 0 stopped_other_loss
			, 0 other_other_gain
			, 0 other_other_loss
			, 0 other_gain
			, 0 other_loss
			, 0 external_gain
			, 0 external_loss
			, 0 a1p_net
			, 0 paying_net
			, 0 stopped_net
			, 0 other_net
			, 0 net
			, 0 end_count
			, 0 a1p_end_count
			, 0 paying_end_count
			, 0 stopped_end_count
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
	select 
		coalesce(d1.displaytext, c.row_header1)::varchar(200) row_header1 -- c.row_header
		--, c.row_header2::varchar(200) row_header2
		, c.row_header1::varchar(20) row_header1_id
		--, ''::varchar(20) row_header2_id
		, c.start_count::int
		, c.a1p_start_count::int
		, c.a1p_gain::int as a1p_real_gain
		, c.a1p_unchanged_gain::int
		, c.a1p_newjoin::int
		, c.a1p_rejoin::int
		, c.a1p_loss::int as a1p_real_loss
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
		, c.rule59_unchanged_gain::int
		, c.stopped_loss::int as stopped_real_loss
		, c.stopped_to_paying::int
		, c.stopped_to_other::int
		, c.stopped_net::int as stopped_real_net
		, c.stopped_other_gain::int
		, c.stopped_other_loss::int
		, c.stopped_end_count::int
-- dbeswick: other_other_gain/loss is returned as other_gain/loss in the SQL function.
		, c.other_other_gain::int other_gain
		, c.other_other_loss::int other_loss
		, c.external_gain::int
		, c.external_loss::int
		, c.net::int
		, c.end_count::int
		, (c.start_count + c.a1p_gain + c.a1p_loss + c.a1p_other_gain+ c.a1p_other_loss + c.paying_gain + c.paying_loss + c.paying_other_gain + c.paying_other_loss + c.stopped_gain + c.stopped_loss + c.stopped_other_gain + c.stopped_other_loss + c.other_other_gain + c.other_other_loss - c.end_count)::int  cross_check
		, c.posted
		, c.unposted
		, c.income_net
		, c.contributors::int
		, c.transactions::int
		, c.annualizedavgcontribution annualisedavgcontribution -- dbeswick: spelling inconsistency
EOS

sql <<
	if @header1 == 'employerid'
<<-EOS	
		, e.lateness::text
		, e.payrollcontactdetail::text
		, e.paidto::date
		, e.paymenttype::text
EOS
else
<<-EOS
		, ''::text lateness
		, ''::text payrollcontactdetail
		, null::date paidto
		, ''::text paymenttype
EOS
end

sql << <<-EOS		
	from 
		withtrans c
		left join displaytext d1 on d1.attribute = '#{@header1}' and d1.id = c.row_header1
EOS

if @header1 == 'employerid'
	   sql << "left join employer e on c.row_header1 = e.companyid"
end

sql << <<-EOS
	where
		c.a1p_gain <> 0
		or c.a1p_loss <> 0
		or c.paying_gain <> 0
		or c.paying_loss <> 0
		or c.stopped_gain <> 0
		or c.stopped_loss <> 0
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
end
