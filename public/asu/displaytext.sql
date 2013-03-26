with delegate_training_text as (
  select 'within six months' as id, 'Within six months' as description
  union all select 'within one year' as id, 'Within one year' as description
  union all select 'within two years' as id, 'Within two years' as description
  union all select 'more than two years' as id, 'More than two years' as description
),
q as 
(
select
	attribute
	, lower(LTRIM(rtrim(id))) as id
	, replace(replace(replace(LTRIM(rtrim(displaytext)),'"', ''),CHAR(9), ''), CHAR(13)+CHAR(10), '') as displaytext
from
	(
/* status values */
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
		, 'nonvoter' as id
		, 'Non-voter' as displaytext
	union all
	select
		'status' as attribute
		, lower(rtrim(ltrim(coalesce(cast(code as varchar(max)), '')))) as id
		, Description
	from
		exits e
	WHERE
		not Code in ('PAYING', 'STOPPED', 'A1P')
	union all
	select
		'status' as attribute
		, lower(rtrim(ltrim(coalesce(cast(code as varchar(max)), '')))) as id
		, Description
	from
		Status 
	where
		Code not in (select Code from Exits)
		and Code not in ('PAYING', 'STOPPED', 'A1P')
/* member names */
	union all 
	select
		'memberid' as attribute
		, cast(memberid as varchar(max)) as id
		, coalesce(surname, '') + ', ' + coalesce(case when isnull(knownname, '') <> '' then knownname else givennames end, '') as displaytext
	from
		members
	where
		MemberID <> 0
/* branch */
	union all
	select 
		'branch' as attribute
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		unionbranch d
/* organiser */
	union all
	select 
		'organiser' as attribute
		, cast(o.code as varchar(max)) as id
		, o.description as displaytext
	from
		organisers o
/* organiser2 */
	union all
	select 
		'organiser2' as attribute
		, cast(o.code as varchar(max)) as id
		, o.description as displaytext
	from
		organisers o
/* locale */
	union all
	select	
		'locale'
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		Locations d
/* employer */
	union all
	select distinct
		'employer' as attribute
		, cast(d.employerid as varchar(max)) as id
		, d.employername as displaytext
	from
		employers d
/* division */
	union all 
	select 
		'division' as attribute
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		WorkDivisions d
/* sector */
	union all
	select 
		'sector' as attribute
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		Sectors d
/* sex */
   	union all
	select
		'sex' as attribute
		, 'M' as id
		, 'Male' as description
   	union all
	select
		'sex' as attribute
		, 'F' as id
		, 'Female' as description
/* hsr */
   	union all
	select
		'hsr' as attribute
		, 'hsr' as id
		, 'HSR' as description
   	union all
	select
		'hsr' as attribute
		, 'hsr deputy' as id
		, 'Deputy HSR' as description
/* delegate */
   	union all
	select
		'delegate' as attribute
		, 'delegate' as id
		, 'Delegate' as description
   	union all
	select
		'delegate' as attribute
		, '' as id
		, 'Non-delegate' as description
/* pay_method */
	union all
	select	
		'pay_method' as attribute
		, cast(d.code as varchar(max)) as id
		, d.description as displaytext
	from
		PayMethods d
/* delegate training intermediate */
   union all 
   select * from 
   	  (select 'delegate_training_intermediate' as attribute) a 
	  cross join delegate_training_text
/* delegate training advanced */
   union all 
   select * from 
      (select 'delegate_training_advanced' as attribute) a
	  cross join delegate_training_text
/* age group */
	union all	
	select	
		'age_group'
		, 'under 25'
		, 'Under 25'
	union all	
	select	
		'age_group'
		, 'under 35'
		, 'Under 35'
	union all	
	select	
		'age_group'
		, 'under 45'
		, 'Under 45'
	union all	
	select	
		'age_group'
		, 'under 55'
		, 'Under 55'
	union all	
	select	
		'age_group'
		, 'under 65'
		, 'Under 65'
	union all	
	select	
		'age_group'
		, 'under 75'
		, 'Under 75'
	union all	
	select	
		'age_group'
		, 'under 85'
		, 'Under 85'
	union all
	select
		'age_group'
		, 'under 95'
		, 'under 95'
	union all	
	select	
		'age_group'
		, '95 and older'
		, '95 and older'
/* recruiter (taken from asuvic signal charts document) */
   union all select 'recruiter', '3_1', 'GT Vic - signal 3 red'
   union all select 'recruiter', '3_2', 'GT Vic - Adam Rodwell'
   union all select 'recruiter', '3_3', 'GT Vic - signal 3 blue'
   union all select 'recruiter', '3_4', 'signal 3 green'
   union all select 'recruiter', '3_5', 'signal 3 magenta'
   union all select 'recruiter', '3_6', 'signal 3 white'
   union all select 'recruiter', '3_7', 'MST - Recruitment'
   union all select 'recruiter', '4_1', 'WP Valid'
   union all select 'recruiter', '4_2', 'WP Existing Member'
   union all select 'recruiter', '4_3', 'WP Invalid'
   union all select 'recruiter', '4_4', 'GT Tas - Kath Ryman'
   union all select 'recruiter', '4_5', 'GT Tas - Ruby TT'
   union all select 'recruiter', '4_6', 'GT Tas - Chris Dodds'
   union all select 'recruiter', '4_7', 'signal 4 black'
   union all select 'recruiter', '8_1', 'OCT'
   union all select 'recruiter', '8_2', 'signal 8 yellow'
   union all select 'recruiter', '8_3', 'signal 8 blue'
   union all select 'recruiter', '8_4', 'Delegate Referral'
   union all select 'recruiter', '8_5', 'Inductions'
   union all select 'recruiter', '8_6', 'signal 8 white'
   union all select 'recruiter', '8_7', 'OCT - Blitz'
)as asdf
)
select * from q