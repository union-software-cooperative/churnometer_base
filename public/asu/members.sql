with training_periods_map as
(
    select 0 as months_start, 6 as months_end, 'within six months' as value
    union all select 6, 12, 'within one year'
    union all select 12, 24, 'within two years'
    union all select 24, 120000, 'more than two years'
)
, delegates as
(
    select 
        distinct memberid
    from 
        memberunionrole 
    where 
        unionrole = 'DELE' 
        and getdate() >= startdate and (enddate is null or enddate < getdate())
)
, q as
(

select

members.memberid
, 
case 
    when employers.division = 'NON' then 'nonvoter'
	/* exited */
    when rtrim(ltrim(coalesce(exitcode, ''))) <> '' then lower(rtrim(ltrim(coalesce(exitcode, ''))))
	/* stopped paying */
    when members.paymethod = 'STOP'
	  or members.directdebitcycle = 'DE' /* de = direct debit declined */
	  then 'stop'
	/* member is on waiver if 'status' is anything other than 'financial' or 'workcover' */
    when rtrim(ltrim(coalesce(members.status, ''))) <> '' 
	  and members.status <> 'FINAN'
	  and members.status <> 'WORK'
	  then lower(rtrim(ltrim(coalesce(members.status, ''))))
else 
    case when payers.memberid is null /* not ever paid */ 
      OR payers.timecreated < members.DateCreated /* or last paid before they were reinstated */
    then 
	  /* don't count people who are resigned, then reinstated immediately as a1p - 
         they are probably dd people making their last payment */
	  case when datediff(d,dateexited,DateCreated) <= 21 
	    then 'paying' 
	    else 'a1p' 
	  end
    else 'paying'
    end
end as status

, lower(rtrim(ltrim(employers.unionbranch))) as branch
, lower(rtrim(ltrim(employers.organiser))) as organiser
, lower(rtrim(ltrim(employers.organiser2))) as organiser2
, lower(rtrim(ltrim(members.location))) as locale -- location is a postgres reserved word

/* note: some employer names have tabs in them */
, members.employer as employer

, lower(rtrim(ltrim(employers.division))) as division
, lower(rtrim(ltrim(employers.sector))) as sector
, lower(rtrim(ltrim(sex))) as sex

-- hsr status
, case 
  when 
      (
       select 
           count(1) 
       from 
           memberunionrole 
       where 
           memberunionrole.memberid = members.memberid 
           and unionrole = 'OH&S' 
           and getdate() >= startdate 
           and (enddate is null or enddate < getdate())
      ) > 0 
      then 'hsr'
  when 
      (
       select 
           count(1) 
       from 
           memberunionrole 
       where 
           memberunionrole.memberid = members.memberid 
           and unionrole = 'OHDEP' 
           and getdate() >= startdate 
           and (enddate is null or enddate < getdate())
      ) > 0 
      then 'hsr deputy'
  end as hsr

-- delegate status
, (
   select 
       top 1 'delegate' 
   from 
       delegates 
   where exists (select 1 from delegates where delegates.memberid = members.memberid)
) as delegate

-- prd status
, case
  when members.paymethod in ('PENDING', 'PRD', 'STOP', 'PRM') then /* PRM = casual payroll */
      'prd'
  else
      lower(rtrim(ltrim(members.paymethod)))
  end as pay_method

-- select the most recent intermediate training session for the member, and use the 
-- training_periods_map to categorise it by how long ago training was completed
, (select top 1
     training_periods_map.value
   from 
     membertraining, 
     training_periods_map, 
     members as train_members
   where 
     train_members.memberid = membertraining.memberid
     and members.memberid = train_members.memberid
     and datediff(month, membertraining.dateoftraining, getdate()) >= training_periods_map.months_start 
     and datediff(month, membertraining.dateoftraining, getdate()) < training_periods_map.months_end
     and membertraining.trainingcourse = 'DINT'
     and exists (select 1 from delegates where delegates.memberid = members.memberid)
     order by dateoftraining desc) as delegate_training_intermediate

-- select the most recent advanced training session, as above
, (
   select top 1
     training_periods_map.value
   from 
     membertraining, 
     training_periods_map, 
     members as train_members
   where 
     train_members.memberid = membertraining.memberid
     and members.memberid = train_members.memberid
     and datediff(month, membertraining.dateoftraining, getdate()) >= training_periods_map.months_start 
     and datediff(month, membertraining.dateoftraining, getdate()) < training_periods_map.months_end
     and membertraining.trainingcourse = 'DADV'
     and exists (select 1 from delegates where delegates.memberid = members.memberid)
     order by dateoftraining desc
) as delegate_training_advanced

-- age group
, case
    when members.dateofbirth is null then null
    when datediff(yy, members.dateofbirth, getdate()) < 25  then 'under 25'
    when datediff(yy, members.dateofbirth, getdate()) < 35  then 'under 35'
    when datediff(yy, members.dateofbirth, getdate()) < 45  then 'under 45'    
    when datediff(yy, members.dateofbirth, getdate()) < 55  then 'under 55'
    when datediff(yy, members.dateofbirth, getdate()) < 65  then 'under 65'
    when datediff(yy, members.dateofbirth, getdate()) < 75  then 'under 75'
    when datediff(yy, members.dateofbirth, getdate()) < 85  then 'under 85'
    when datediff(yy, members.dateofbirth, getdate()) < 95  then 'under 95'
    when datediff(yy, members.dateofbirth, getdate()) >= 95  then '95 and older'
end as age_group

-- Signals 3, 4 and 8 specify different recruiting entities. Only one of each signal should be set at one time, otherwise they are placed in the 'multiple assignment' category
, case
  when members.signal3 <> 0 and members.signal4 <> 0 or members.signal4 <> 0 and members.signal8 <> 0 or members.signal3 <> 0 and members.signal8 <> 0 then 'error'
  when members.signal3 = 1 then '3_1'
  when members.signal3 = 2 then '3_2'
  when members.signal3 = 3 then '3_3'
  when members.signal3 = 4 then '3_4'
  when members.signal3 = 5 then '3_5'
  when members.signal3 = 6 then '3_6'
  when members.signal3 = 7 then '3_7'
  when members.signal4 = 1 then '4_1'
  when members.signal4 = 2 then '4_2'
  when members.signal4 = 3 then '4_3'
  when members.signal4 = 4 then '4_4'
  when members.signal4 = 5 then '4_5'
  when members.signal4 = 6 then '4_6'
  when members.signal4 = 7 then '4_7'
  when members.signal8 = 1 then '8_1'
  when members.signal8 = 2 then '8_2'
  when members.signal8 = 3 then '8_3'
  when members.signal8 = 4 then '8_4'
  when members.signal8 = 5 then '8_5'
  when members.signal8 = 6 then '8_6'
  when members.signal8 = 7 then '8_7'
end as recruiter

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
    members.memberid <> 0 and employers.employerid <> 0

)
select * from q