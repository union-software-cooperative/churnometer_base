


select 
	members.memberid
	, employers.organiser2 as lead
	, employers.organiser as org
	, employers.region
	, members.division
	, members.[section]
	, members.department
	, members.floor
	, members.location
	, employers.employerid as employer
	, employers.division as  industry
	, members.paymethod as pay_method
	, chargescale & "" as charge_scale
	, iif(date() - iif(members.dateofbirth is null,#1-1-1900#, members.dateofbirth ) / 365 < 35, 'under35', 'over35') as age_group
	, members.sex as gender
	, members.employer2 as supporter_type
	, members.unionrole as union_role
	, members.signal8 as signal8
	, members.mainlanguage as arrears_cycle
	, iif(trim(exitcode & "") <> ""
		, trim(exitcode & "")
		, iif(iif(signal8 is null, 0, signal8) > 0 
			, 'stopped' 
			, iif(payers.memberid is null
				, 'a1p'
				, 'paying'
			)
		)
	) as status
from
	(
		members
		left join employers on members.employer = employers.employerid
	)
	left join (
		select distinct 
			memberid
		from	
			receipts
		where
			receiptAmount > 0
	) as payers on members.memberid = payers.memberid
	