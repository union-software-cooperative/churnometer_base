select
	attribute
	, lower(LTRIM(rtrim(id))) as id
	, replace(replace(replace(LTRIM(rtrim(displaytext)),'"', ''),CHAR(9), ''), CHAR(13)+CHAR(10), '') as displaytext
from
	(
	select
		'status' as attribute
		, 'A1P' as id
		, 'Application In' as displaytext
	union all
	select
		'status' as attribute
		, 'PAYING' as id
		, 'Paid-Up' as displaytext
	union all	
	select
		'status' as attribute
		, 'STOPPED' as id
		, 'In Arrears' as displaytext
	union all
	select
		'status' as attribute
		, cast(code as varchar(max)) as id
		, Description
	from
		exits e
	WHERE
		not Code in ('PAYING', 'STOPPED', 'A1P')
	union all
	select
		'status' as attribute
		, cast(code as varchar(max)) as id
		, Description
	from
		Status 
	where
		Code not in (select Code from Exits)
		and Code not in ('PAYING', 'STOPPED', 'A1P')
	union all 
	select
		'memberid' as attribute
		, cast(memberid as varchar(max)) as id
		, coalesce(surname, '') + ', ' + coalesce(case when isnull(knownname, '') <> '' then knownname else givennames end, '') as displaytext
	from
		members
	union all
	select 
		'col0' as attribute
		, cast(o.code as varchar(max)) as id
		, o.description as displaytext
	from
		organisers o
	union all
	select 
		'col1' as attribute
		, cast(o.code as varchar(max)) as id
		, o.description as displaytext
	from
		organisers o
	union all
	select 
		'col2' as attribute 
		, cast(r.code as varchar(max)) as id
		, r.description as displaytext 
	from 
		regions r
	union all 
	select 
		'col3'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		WorkDivisions d
	union all
	select 
		'col4'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		Sections d
	union all
	select 
		'col5'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		Departments d
	union all
	select 
		'col6'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		Floors d
		union all
	select	
		'col7'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		Locations d
	union all
	select
		'col8'
		, cast(employerid as varchar(max)) as id
		, employername as displaytext
	from
		Employers
	union all
	select	
		'col9'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		divisions d	
	union all
	select	
		'col10'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		PayMethods d
	union all	
	select	
		'col11'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		SubscriptionChargeScale d	
	union all	
	select	
		'col12'
		, 'over35'
		, '35 and over'
	union all
	select
		'col12'
		, 'under35'
		, 'under 35'
		union all	
	select	
		'col13'
		, 'M'
		, 'Male'
	union all
	select
		'col13'
		, 'F'
		, 'Female'
		union all
	select	
		'col14'
		, 'promoter'
		, 'Promoter'
	union all
	select
		'col14'
		, 'detractor'
		, 'Detractor'
	union all
	select
		'col14'
		, 'advocate'
		, 'Advocate'
	union all
	select
		'col15'
		, '30'
		, 'Delegate'
	union all
	select 
		'col15'
		, '10'
		, 'Contact'
	union all
	select
		'col16'
		, '0'
		, 'Paid-up'
	union all
	select
		'col17'
		, '0'
		, 'Development'
	union all
	select
		'col19'
		, '-1'
		, 'Growth'
)as asdf
