select
	members.memberid
	, 
	case 
		when ChargeScale = 'life' then 'life'
		when PayMethod = 'non' then  lower(rtrim(ltrim(coalesce(members.status, 'nofee'))))
		when rtrim(ltrim(coalesce(exitcode, ''))) <> ''	then lower(rtrim(ltrim(coalesce(exitcode, ''))))
	else 
		case when 
			coalesce(members.signal8, 0) > 0 --OR payers.timecreated < DATEADD(y,-42,getdate())
		then 'stopped' 
		else 
			case when payers.memberid is null /* not ever paid */ OR payers.timecreated < members.DateCreated /* or last paid before they were reinstated */
			/* don't count people who are resigned, then reinstated immediately as a1p - they are probably dd people making their last payment */
			then case when datediff(d,dateexited,DateCreated) <= 21 then 'paying' else 'a1p' end
			else 'paying'
			end
		end
	end as status
	, lower(rtrim(ltrim(employers.organiser2 ))) as lead
	, lower(rtrim(ltrim(employers.organiser))) as org
	, lower(rtrim(ltrim(employers.region))) as region
	, lower(rtrim(ltrim(members.division))) as division 
	, lower(rtrim(ltrim(members.[section]))) as section
	, lower(rtrim(ltrim(members.department))) as department
	, lower(rtrim(ltrim(members.floor))) as floor
	, lower(rtrim(ltrim(members.location))) as locale -- location is a postgres reserved word
	, lower(rtrim(ltrim(employers.employerid))) as employer
	, lower(rtrim(ltrim(employers.division))) as industry
	, lower(rtrim(ltrim(members.paymethod))) as pay_method
	, lower(rtrim(ltrim(coalesce(case when chargescale like 'E%' then substring(chargescale,2,len(chargescale)-1) else chargescale end,'')))) as charge_scale
	, lower(rtrim(ltrim(case when not members.dateofbirth  IS null then 
	  case when 
		datediff(yy
			, coalesce( members.dateofbirth,'1-1-1900')
			, getdate()
		) < 35
	  then 'under35'
	  else 'over35'
	  end else '' end))) as age_group
	, lower(rtrim(ltrim(members.sex))) as gender
	, lower(rtrim(ltrim(members.FileNo))) as support_type -- (advocate, detractor, promoter)
	, lower(rtrim(ltrim(members.unionrole))) as union_role
	, lower(rtrim(ltrim(members.signal8))) as signal8
	, lower(rtrim(ltrim(members.mainlanguage))) as arrears_cycle
	, lower(rtrim(ltrim(members.EWBNo))) as emptype -- fulltime, partTime, casual
	, 'asuqld' as branch
from
	members
	left join employers on members.employer = employers.employerid
	left join (
		select --distinct 
			memberid
			, MAX(timecreated) timecreated
		from	
			receiptheader
		where
			receiptAmount > 0
		group by 
			memberid
	) as payers on members.memberid = payers.memberid
where
	members.memberid <> 0

