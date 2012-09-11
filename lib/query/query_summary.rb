require './lib/query/query_filter'
require './lib/query/query_sites_at_date'
require './lib/settings'
require 'nokogiri'

class QuerySummary < QueryFilter
  def initialize(churn_db, header1, start_date, end_date, with_trans, site_constraint, filter_xml)
    super(churn_db, filter_xml)
    @source = churn_db.fact_table
    @header1 = header1
    @start_date = start_date
    @end_date = end_date
    @with_trans = with_trans
    @site_constraint = site_constraint
  end

  def query_string
    dte = Time.at(0)

    db = @churn_db.db

    filter = 
      if @site_constraint.empty?
        filter_terms()
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
        company_filter['id'] = QuerySitesAtDate.new(@source, @header1, header2, dte, @with_trans, xml_filter).execute.collect { |record| record['companyid'] }
        #filter['companyid']:=xml_array_to_array(xpath('/search/companyid', site_xml));
        
        # keep original status filter
        filter['status'] = xml_array_to_array('/search/status', xml)
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
			changedate <= #{db.sql_date(@end_date)} -- we need to count every value since Churnobyls start to determine start_count.  But everything after enddate can be ignored.
  		and (#{filter['branchid'].empty?} or coalesce(branchid,'') = any (#{db.sql_array(filter['branchid'], 'varchar')}) or (coalesce(branchid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['branchid'], 'varchar')})))
			and (#{filter['companyid'].empty?} or coalesce(companyid,'') = any (#{db.sql_array(filter['companyid'], 'varchar')})  or (coalesce(companyid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['companyid'], 'varchar')})))
			and (#{filter['org'].empty?} or coalesce(org,'') = any (#{db.sql_array(filter['org'], 'varchar')})  or (coalesce(org,'') = '' and 'unassigned' = any (#{db.sql_array(filter['org'], 'varchar')})) )
			and (#{filter['areaid'].empty?} or coalesce(areaid,'') = any (#{db.sql_array(filter['areaid'], 'varchar')})  or (coalesce(areaid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['areaid'], 'varchar')})))
			and (#{filter['lead'].empty?} or coalesce(lead,'') = any (#{db.sql_array(filter['lead'], 'varchar')})  or (coalesce(lead,'') = '' and 'unassigned' = any (#{db.sql_array(filter['lead'], 'varchar')})))
			and (#{filter['nuwelectorate'].empty?} or coalesce(nuwelectorate,'') = any (#{db.sql_array(filter['nuwelectorate'], 'varchar')})  or (coalesce(nuwelectorate,'') = '' and 'unassigned' = any (#{db.sql_array(filter['nuwelectorate'], 'varchar')})))
			and (#{filter['state'].empty?} or coalesce(state,'') = any (#{db.sql_array(filter['state'], 'varchar')})  or (coalesce(state,'') = '' and 'unassigned' = any (#{db.sql_array(filter['state'], 'varchar')})))
			and (#{filter['industryid'].empty?} or coalesce(industryid,0)::varchar(5) = any (#{db.sql_array(filter['industryid'], 'varchar')})  or (coalesce(industryid,0) = 0 and 'unassigned' = any (#{db.sql_array(filter['industryid'], 'varchar')})))
			and (#{filter['del'].empty?} or coalesce(del,0)::varchar(5) = any (#{db.sql_array(filter['del'], 'varchar')})  or (coalesce(del,0) = 0 and 'unassigned' = any (#{db.sql_array(filter['del'], 'varchar')})))
			and (#{filter['hsr'].empty?} or coalesce(hsr,0)::varchar(5) = any (#{db.sql_array(filter['hsr'], 'varchar')})  or (coalesce(hsr,0) = 0 and 'unassigned' = any (#{db.sql_array(filter['hsr'], 'varchar')})))
			and (#{filter['feegroup'].empty?} or coalesce(feegroupid,'') = any (#{db.sql_array(filter['feegroup'], 'varchar')})  or (coalesce(feegroupid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['feegroup'], 'varchar')})))
			
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
	

			and (#{filter['supportstaffid'].empty?} or coalesce(supportstaffid,'') = any (#{db.sql_array(filter['supportstaffid'], 'varchar')})  or (coalesce(supportstaffid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['supportstaffid'], 'varchar')})))
			and (#{filter['employerid'].empty?} or coalesce(employerid,'') = any (#{db.sql_array(filter['employerid'], 'varchar')})  or (coalesce(employerid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['employerid'], 'varchar')})))
			and (#{filter['hostemployerid'].empty?} or coalesce(hostemployerid,'') = any (#{db.sql_array(filter['hostemployerid'], 'varchar')})  or (coalesce(hostemployerid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['hostemployerid'], 'varchar')})))
			and (#{filter['employmenttypeid'].empty?} or coalesce(employmenttypeid,'') = any (#{db.sql_array(filter['employmenttypeid'], 'varchar')})  or (coalesce(employmenttypeid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['employmenttypeid'], 'varchar')})))
			
			and (#{filter['not_supportstaffid'].empty?} or (not coalesce(supportstaffid, '') = any (#{db.sql_array(filter['not_supportstaffid'], 'varchar')}) or (coalesce(supportstaffid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_supportstaffid'], 'varchar')}))))
			and (#{filter['not_employerid'].empty?} or (not coalesce(employerid, '') = any (#{db.sql_array(filter['not_employerid'], 'varchar')}) or (coalesce(employerid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_employerid'], 'varchar')}))))
			and (#{filter['not_hostemployerid'].empty?} or (not coalesce(hostemployerid, '') = any (#{db.sql_array(filter['not_hostemployerid'], 'varchar')}) or (coalesce(hostemployerid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_hostemployerid'], 'varchar')}))))
			and (#{filter['not_employmenttypeid'].empty?} or (not coalesce(employmenttypeid, '') = any (#{db.sql_array(filter['not_employmenttypeid'], 'varchar')}) or (coalesce(employmenttypeid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_employmenttypeid'], 'varchar')}))))
			
			and (#{filter['paymenttypeid'].empty?} or coalesce(paymenttypeid,'') = any (#{db.sql_array(filter['paymenttypeid'], 'varchar')})  or (coalesce(paymenttypeid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['paymenttypeid'], 'varchar')})))
			
			and (#{filter['not_paymenttypeid'].empty?} or (not coalesce(paymenttypeid, '') = any (#{db.sql_array(filter['not_paymenttypeid'], 'varchar')}) or (coalesce(paymenttypeid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_paymenttypeid'], 'varchar')}))))
			
	)
	, userselections as 
	(
		select
			*
		from
			nonstatusselections
		where
			(#{filter['status'].empty?} or coalesce(status,'') = any (#{db.sql_array(filter['status'], 'varchar')})  or (coalesce(status,'') = '' and 'unassigned' = any (#{db.sql_array(filter['status'], 'varchar')})))
			and (#{filter['statusstaffid'].empty?} or coalesce(statusstaffid,'') = any (#{db.sql_array(filter['statusstaffid'], 'varchar')})  or (coalesce(statusstaffid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['statusstaffid'], 'varchar')})))
			and (#{filter['not_statusstaffid'].empty?} or (not coalesce(statusstaffid, '') = any (#{db.sql_array(filter['not_statusstaffid'], 'varchar')}) or (coalesce(statusstaffid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_statusstaffid'], 'varchar')}))))
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
		, ( sum(amount::numeric) / count(distinct t.memberid)::numeric ) / (#{db.sql_date(@end_date)}::date - #{db.sql_date(@start_date)}::date) * 365::numeric annualizedAvgContribution
		, count(*) transactions
	from
		transactionfact t
		inner join nonstatusselections u1 on
			u1.net = 1
			and u1.changeid = t.changeid
	where
		t.creationdate > #{db.sql_date(@start_date)}
		and t.creationdate <= #{db.sql_date(@end_date)}
		-- statusstaffid is special.  Rather than members and their transactions being assigned to an organising area
		-- statusstaffid is about who actually changed a status or who actually posted the transaction.
		-- for this reason, we filter status staff on staffid field in transactionfact.  
		and (#{filter['statusstaffid'].empty?} or coalesce(staffid,'') = any (#{db.sql_array(filter['statusstaffid'], 'varchar')})  or (coalesce(staffid,'') = '' and 'unassigned' = any (#{db.sql_array(filter['statusstaffid'], 'varchar')})))
		and (#{filter['not_statusstaffid'].empty?} or (not coalesce(staffid, '') = any (#{db.sql_array(filter['not_statusstaffid'], 'varchar')}) or (coalesce(staffid, '')  = '' and not 'unassigned' = any (#{db.sql_array(filter['not_statusstaffid'], 'varchar')}))))
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
			, sum(case when changedate <= #{db.sql_date(@start_date)} then net else 0 end) as start_count
			, sum(case when changedate <= #{db.sql_date(@start_date)} and status = '14' then net else 0 end) as a1p_start_count -- cant use a1pgain + a1ploss because they only count when a status changes, where as we want every a1p value in the selection, even if it is a transfer
			, sum(case when changedate <= #{db.sql_date(@start_date)} and status = '1' then net else 0 end) as paying_start_count
			, sum(case when changedate <= #{db.sql_date(@start_date)} and status = '11' then net else 0 end) as stopped_start_count
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then a1pgain else 0 end) a1p_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and _changeid is null then a1pgain else 0 end) a1p_unchanged_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and coalesce(_status, '') = '' then a1pgain else 0 end) a1p_newjoin
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and coalesce(_status, '') <>'' then a1pgain else 0 end) a1p_rejoin			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then a1ploss else 0 end) a1p_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and coalesce(_status,'') = '1' then a1ploss else 0 end) a1p_to_paying
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and coalesce(_status,'') <> '1' then a1ploss else 0 end) a1p_to_other			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then payinggain else 0 end) paying_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then payingloss else 0 end) paying_loss

			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then stoppedgain else 0 end) stopped_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and _changeid is null then stoppedgain else 0 end) stopped_unchanged_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and _changeid is null and coalesce(_status,'') = '3' then loss else 0 end) rule59_unchanged_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then stoppedloss else 0 end) stopped_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and coalesce(_status,'') = '1' then stoppedloss else 0 end) stopped_to_paying
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and coalesce(_status,'') <> '1' then stoppedloss else 0 end) stopped_to_other			
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and status = '14' then othergain else 0 end) a1p_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and status = '14' then otherloss else 0 end) a1p_other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and status = '1' then othergain else 0 end) paying_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and status = '1' then otherloss else 0 end) paying_other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and status = '11' then othergain else 0 end) stopped_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and status = '11' then otherloss else 0 end) stopped_other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and not (status = '1' or status = '14' or status = '11') then othergain else 0 end) other_other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and not (status = '1' or status = '14' or status = '11') then otherloss else 0 end) other_other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then othergain else 0 end) other_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then otherloss else 0 end) other_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and not internalTransfer then othergain else 0 end) external_gain
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} and not internalTransfer then otherloss else 0 end) external_loss
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then a1pgain+a1ploss else 0 end) a1p_net
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then payinggain+payingloss else 0 end) paying_net
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then stoppedgain+stoppedloss else 0 end) stopped_net
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then othergain+otherloss else 0 end) other_net
			, sum(case when changedate > #{db.sql_date(@start_date)} and changedate <= #{db.sql_date(@end_date)} then coalesce(c.net,0) else 0 end) net
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
