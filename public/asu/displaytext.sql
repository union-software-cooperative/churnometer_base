select
	attribute
	, lower(LTRIM(rtrim(id))) as id
	, replace(replace(replace(LTRIM(rtrim(displaytext)),'"', ''),CHAR(9), ''), CHAR(13)+CHAR(10), '') as displaytext
from
	(
	select
		'status' as attribute
		, 'A1P' as id
		, 'New Application' as displaytext
	union all
	select
		'status' as attribute
		, 'PAYING' as id
		, 'Paying' as displaytext
	union all	
	select
		'status' as attribute
		, 'STOPPED' as id
		, 'Stopped Paying' as displaytext
	union all
	select
		'status' as attribute
		, 'nofee' as id
		, 'NON-FEE PAYING' as displaytext
	union all
	select
		'status' as attribute
		, lower(rtrim(ltrim(coalesce(cast(code as varchar(max)), '')))) as id
		, Description
	from
		exits e
	WHERE
		not Code in ('PAYING', 'STOPPED', 'A1P', 'nofee')
	union all
	select
		'status' as attribute
		, lower(rtrim(ltrim(coalesce(cast(code as varchar(max)), '')))) as id
		, Description
	from
		Status 
	where
		Code not in (select Code from Exits)
		and Code not in ('PAYING', 'STOPPED', 'A1P', 'nofee')
	union all 
	select
		'memberid' as attribute
		, cast(memberid as varchar(max)) as id
		, coalesce(surname, '') + ', ' + coalesce(case when isnull(knownname, '') <> '' then knownname else givennames end, '') as displaytext
	from
		members
	where
		MemberID <> 0
	union all
	select 
		'lead' as attribute
		, cast(o.code as varchar(max)) as id
		, o.description as displaytext
	from
		organisers o
	union all
	select 
		'org' as attribute
		, cast(o.code as varchar(max)) as id
		, o.description as displaytext
	from
		organisers o
	union all
	select 
		'region' as attribute 
		, cast(r.code as varchar(max)) as id
		, r.description as displaytext 
	from 
		regions r
	union all 
	select 
		'division'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		WorkDivisions d
	union all
	select 
		'section'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		Sections d
	union all
	select 
		'department'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		Departments d
	union all
	select 
		'floor'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		Floors d
		union all
	select	
		'locale'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		Locations d
	union all
	select
		'employer'
		, cast(employerid as varchar(max)) as id
		, employername as displaytext
	from
		Employers
	union all
	select	
		'industry'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		divisions d	
	union all
	select	
		'pay_method'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		PayMethods d
	union all	
	select	
		'charge_scale'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		SubscriptionChargeScale d	
	union all	
	select	
		'age_group'
		, 'over35'
		, '35 and over'
	union all
	select
		'age_group'
		, 'under35'
		, 'under 35'
		union all	
	select	
		'gender'
		, 'M'
		, 'Male'
	union all
	select
		'gender'
		, 'F'
		, 'Female'
		union all
	select	
		'support_type'
		, 'promoter'
		, 'Promoter'
	union all
	select
		'support_type'
		, 'detractor'
		, 'Detractor'
	union all
	select
		'support_type'
		, 'advocate'
		, 'Advocate'
	union all
	--select
	--	'col15'
	--	, '30'
	--	, 'Delegate'
	--union all
	--select 
	--	'col15'
	--	, '10'
	--	, 'Contact'
	select 
		'union_role'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		WorkplaceRoles d	 
	union all
	select
		'signal8'
		, '0'
		, 'Paid-up'
	union all 
	select 
		'signal8'
		, '1'
		, 'Phone call'
	union all 
	select 
		'signal8'
		, '2'
		, 'Letter 1 (no resignation)'
	union all 
	select 
		'signal8'
		, '3'
		, 'Letter 1 (resignation)'
	union all 
	select 
		'signal8'
		, '4'
		, 'Letter 2 (no resignation)'
	union all 
	select 
		'signal8'
		, '5'
		, 'Letter 2 (resignation)'
	union all 
	select 
		'signal8'
		, '6'
		, 'Debt Collector'
	union all
	select
		'branch'
		, 'asuqld'
		, 'ASU Queensland'
	union all
	select
		'employer_group'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
				from
		EmployerGroups d
)as asdf