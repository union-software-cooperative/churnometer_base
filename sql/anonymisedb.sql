-- WARNING This script will destroy the churnometer database!!!!
-- It is designed to create a demo version of churnometer as a favourable subset of this data

drop table if exists displaytext_anonymisedb;
create table displaytext_anonymisedb (like displaytext including constraints including indexes including defaults);
insert into displaytext_anonymisedb select * from displaytext;

drop table if exists transactionfact_anonymisedb;
create table transactionfact_anonymisedb (like transactionfact including constraints including indexes including defaults);
insert into transactionfact_anonymisedb select * from transactionfact;

drop table if exists employer_anonymisedb;
create table employer_anonymisedb (like employer including constraints including indexes including defaults);
insert into employer_anonymisedb select * from employer;

drop table if exists memberfacthelper5 ;

create table memberfacthelper5 (like memberfacthelper4 including constraints including indexes including defaults);

with members as ( 
	select distinct memberid from memberfacthelper4 
)
, randomised as (
	select random() * (select count(*) from members) rand, memberid from members
), rand as (
	select rand, memberid from randomised order by rand limit 4000 
), nowpaying as
(
	select 
		memberid
	from
		memberfacthelper4
	where
		changeid in 
		(
			select 
				max(changeid)
			from 
				memberfacthelper4
			group by 
				memberid
		)
		and net = 1
		and status = '1'
)
, randomisedpaying as (
	select random() * (select count(*) from nowpaying) rand, memberid from nowpaying
), paying as (
	select rand, memberid from randomisedpaying where memberid not in (select memberid from rand) order by rand limit 1000 
), top5000 as (
	select memberid from rand
	union all
	select memberid from paying
)
insert into memberfacthelper5 select * from memberfacthelper4 where memberid in (select memberid from top5000);
grant select on memberfacthelper5 to churnuser;

insert into displaytext (id, displaytext, attribute) select 'dbo', 'dbo', 'statusstaffid';
insert into displaytext (id, displaytext, attribute) select 'Jbutterfield', 'janine', 'statusstaffid';

insert into displaytext (id, displaytext, attribute) select 'ForeDefOther', 'janine', 'nuwelectorate';
insert into displaytext (id, displaytext, attribute) select 'MR', 'janine', 'nuwelectorate';
insert into displaytext (id, displaytext, attribute) select 'Qld', 'janine', 'nuwelectorate';
insert into displaytext (id, displaytext, attribute) select 'SA', 'janine', 'nuwelectorate';
insert into displaytext (id, displaytext, attribute) select 'QLD', 'janine', 'nuwelectorate';
insert into displaytext (id, displaytext, attribute) select 'TasNT', 'janine', 'nuwelectorate';
insert into displaytext (id, displaytext, attribute) select 'WA', 'janine', 'nuwelectorate';

insert into displaytext (id, displaytext, attribute) select distinct feegroupid, '', 'feegroupid' from memberfacthelper5;
 
drop table if exists mash;

with translation as 
(
	select 'b' gid, 'branchid' att, 'Branch' des, 2 cnt
	union 
	select '', 'industryid', 'Industry', 5
	union
	select 'o',  'org', 'Organiser', 10
	union
	select 's', 'supportstaffid', 'Support Staff', 5
	union
	select 'e', 'employerid', 'Employer', 100
	union
	select 'h', 'hostemployerid', 'Parent Company', 100
	union
	select 'l', 'lead', 'Lead Organiser', 3
	union
	select 'c', 'companyid', 'Site', 300
	union
	select 'a', 'areaid', 'Area', 20
	union
	select 'm', 'memberid', 'Member', 500000
	union
	select 'd', 'statusstaffid', 'Clerk', 5
	union
	select 'f', 'feegroupid', 'Fee Level', 5
	union 
	select 'el', 'nuwelectorate', 'Electorate', 5
)
, ranked as 
(
select d.*,  gid, des, rank() over (partition by attribute order by random(), displaytext) rnk, cnt
	from 
		displaytext d
		inner join translation t on d.attribute = t.att
	where 
		not (attribute = 'branchid' and not (id = 'NV' or id = 'NG'))
)
, grouped as 
(
select *,  mod(rnk,cnt)+1 grp from ranked
)
select attribute, id oldid, gid || cast(grp as text) newid, displaytext olddisplaytext, des || ' ' || cast(grp as text) as newdisplaytext into mash from grouped
;


delete from displaytext where  attribute in ('branchid', 'industryid', 'org', 'lead', 'supportstaffid', 'employerid', 'lead', 'companyid', 'areaid', 'nuwelectorate', 'feegroupid', 'memberid', 'hostemployerid', 'statusstaffid')
;

insert into displaytext
select
	attribute
	, newid
	, case when attribute = 'memberid' then olddisplaytext else newdisplaytext end
from 
	mash
group by
	attribute
	, newid
	, case when attribute = 'memberid' then olddisplaytext else newdisplaytext end
;

update displaytext set displaytext = 'Construction' where attribute = 'branchid' and id = 'b1';
update displaytext set displaytext = 'Warehousing' where attribute = 'branchid' and id = 'b2';

update 
	memberfacthelper5
set
	branchid = newid
from
	mash m 
where
	memberfacthelper5.branchid = m.oldid and m.attribute = 'branchid'
;

update 
	memberfacthelper5
set
	industryid = cast(newid as int)
from
	mash m 
where
	memberfacthelper5.industryid = cast(m.oldid as int) and m.attribute = 'industryid'
;


update 
	memberfacthelper5
set
	lead = newid
from
	mash m 
where
	memberfacthelper5.lead = m.oldid and m.attribute = 'lead'
;


update 
	memberfacthelper5
set
	org = newid
from
	mash m 
where
	memberfacthelper5.org = m.oldid and m.attribute = 'org'
;


update 
	memberfacthelper5
set
	employerid = newid
from
	mash m 
where
	memberfacthelper5.employerid = m.oldid and m.attribute = 'employerid'
;

update 
	memberfacthelper5
set
	hostemployerid = newid
from
	mash m 
where
	memberfacthelper5.hostemployerid = m.oldid and m.attribute = 'hostemployerid'
;


update 
	memberfacthelper5
set
	companyid = newid
from
	mash m 
where
	memberfacthelper5.companyid = m.oldid and m.attribute = 'companyid'
;


update 
	memberfacthelper5
set
	supportstaffid = newid
from
	mash m 
where
	memberfacthelper5.supportstaffid = m.oldid and m.attribute = 'supportstaffid'
;

update 
	memberfacthelper5
set
	areaid = newid
from
	mash m 
where
	memberfacthelper5.areaid = m.oldid and m.attribute = 'areaid'
;

update 
	memberfacthelper5
set
	nuwelectorate = newid
from
	mash m 
where
	memberfacthelper5.nuwelectorate = m.oldid and m.attribute = 'nuwelectorate'
;

update 
	memberfacthelper5
set
	feegroupid = newid
from
	mash m 
where
	memberfacthelper5.feegroupid = m.oldid and m.attribute = 'feegroupid'
;


update 
	memberfacthelper5
set
	memberid = newid
from
	mash m 
where
	memberfacthelper5.memberid = m.oldid and m.attribute = 'memberid'
;

update 
	memberfacthelper5
set
	statusstaffid = newid
from
	mash m 
where
	memberfacthelper5.statusstaffid = m.oldid and m.attribute = 'statusstaffid'
;

update transactionfact
set
	memberid = newid
from
	mash m 
where
	transactionfact.memberid = m.oldid and m.attribute = 'memberid'
;

delete from transactionfact where not memberid in (select memberid from memberfacthelper5);

update transactionfact
set
	siteid = newid
from
	mash m 
where
	transactionfact.siteid = m.oldid and m.attribute = 'companyid'
;

update transactionfact
set
	staffid = newid
from
	mash m 
where
	transactionfact.staffid = m.oldid and m.attribute = 'statusstaffid'
;


update transactionfact
set
	employerid = newid
from
	mash m 
where
	transactionfact.employerid = m.oldid and m.attribute = 'employerid'
;

update 
	memberfact
set
	memberid = newid
from
	mash m 
where
	memberfact.memberid = m.oldid and m.attribute = 'memberid'
;

update 
	memberfact
set
	oldbranchid = newid
from
	mash m 
where
	memberfact.oldbranchid = m.oldid and m.attribute = 'branchid'
;

update 
	memberfact
set
	oldindustryid = cast(newid as int)
from
	mash m 
where
	memberfact.oldindustryid = cast(m.oldid as int) and m.attribute = 'industryid'
;


update 
	memberfact
set
	oldlead = newid
from
	mash m 
where
	memberfact.oldlead = m.oldid and m.attribute = 'lead'
;


update 
	memberfact
set
	oldorg = newid
from
	mash m 
where
	memberfact.oldorg = m.oldid and m.attribute = 'org'
;


update 
	memberfact
set
	oldemployerid = newid
from
	mash m 
where
	memberfact.oldemployerid = m.oldid and m.attribute = 'employerid'
;

update 
	memberfact
set
	oldhostemployerid = newid
from
	mash m 
where
	memberfact.oldhostemployerid = m.oldid and m.attribute = 'hostemployerid'
;


update 
	memberfact
set
	oldcompanyid = newid
from
	mash m 
where
	memberfact.oldcompanyid = m.oldid and m.attribute = 'companyid'
;


update 
	memberfact
set
	oldsupportstaffid = newid
from
	mash m 
where
	memberfact.oldsupportstaffid = m.oldid and m.attribute = 'supportstaffid'
;

update 
	memberfact
set
	oldareaid = newid
from
	mash m 
where
	memberfact.oldareaid = m.oldid and m.attribute = 'areaid'
;

update 
	memberfact
set
	oldnuwelectorate = newid
from
	mash m 
where
	memberfact.oldnuwelectorate = m.oldid and m.attribute = 'nuwelectorate'
;


update 
	memberfact
set
	oldfeegroupid = newid
from
	mash m 
where
	memberfact.oldfeegroupid = m.oldid and m.attribute = 'feegroupid'
;


update 
	memberfact
set
	oldstatusstaffid = newid
from
	mash m 
where
	memberfact.oldstatusstaffid = m.oldid and m.attribute = 'statusstaffid'
;


update 
	memberfact
set
	newbranchid = newid
from
	mash m 
where
	memberfact.newbranchid = m.oldid and m.attribute = 'branchid'
;

update 
	memberfact
set
	newindustryid = cast(newid as int)
from
	mash m 
where
	memberfact.newindustryid = cast(m.oldid as int) and m.attribute = 'industryid'
;


update 
	memberfact
set
	newlead = newid
from
	mash m 
where
	memberfact.newlead = m.oldid and m.attribute = 'lead'
;


update 
	memberfact
set
	neworg = newid
from
	mash m 
where
	memberfact.neworg = m.oldid and m.attribute = 'org'
;


update 
	memberfact
set
	newemployerid = newid
from
	mash m 
where
	memberfact.newemployerid = m.oldid and m.attribute = 'employerid'
;

update 
	memberfact
set
	newhostemployerid = newid
from
	mash m 
where
	memberfact.newhostemployerid = m.oldid and m.attribute = 'hostemployerid'
;


update 
	memberfact
set
	newcompanyid = newid
from
	mash m 
where
	memberfact.newcompanyid = m.oldid and m.attribute = 'companyid'
;


update 
	memberfact
set
	newsupportstaffid = newid
from
	mash m 
where
	memberfact.newsupportstaffid = m.oldid and m.attribute = 'supportstaffid'
;

update 
	memberfact
set
	newareaid = newid
from
	mash m 
where
	memberfact.newareaid = m.oldid and m.attribute = 'areaid'
;
update 
	memberfact
set
	newnuwelectorate = newid
from
	mash m 
where
	memberfact.newnuwelectorate = m.oldid and m.attribute = 'nuwelectorate'
;

update 
	memberfact
set
	newfeegroupid = newid
from
	mash m 
where
	memberfact.newfeegroupid = m.oldid and m.attribute = 'feegroupid'
;

update 
	memberfact
set
	newstatusstaffid = newid
from
	mash m 
where
	memberfact.newstatusstaffid = m.oldid and m.attribute = 'statusstaffid'
;


delete from employer where not companyid in (
	select min(oldid) keepthis from mash where attribute = 'employerid' group by newid 
)
;

update 
	employer
set
	companyid = newid
	, companyname = newdisplaytext
from
	mash m
where
	employer.companyid = m.oldid and attribute = 'employerid'
;



delete from displaytext where not id in (select memberid from memberfacthelper5) and attribute = 'memberid';

with names as
	(
	select
		substr(displaytext, 0,strpos(displaytext, ',')) lastname
		, substr(displaytext, strpos(displaytext, ',')+2, length(displaytext) - strpos(displaytext, ',')-1) firstname
	from
		displaytext 
	where
		attribute = 'memberid'
)
, lastnames as 
(
select
	lastname, rank() over (order by lastname)
from 
	names
where
	not lastname is null and length(lastname) > 2
	and not lastname in ('0..', '123213')
)
, firstnames as 
(
select
	firstname, rank() over (order by firstname)
from 
	names
where
	not firstname is null and length(firstname) > 2
)
, mixednames as 
(
select 
	firstname
	, lastname
	
from
	firstnames
	inner join lastnames on firstnames.rank = lastnames.rank and firstnames.firstname <> lastnames.lastname
)
, rankednames as
(
select 
	firstname
	, lastname
	, rank() over (order by random()) rank
from
	mixednames
)
, displaytextranked as
(
	select
		*
		, mod(rank() over (order by id),5000) + 1 rank
	from
		displaytext
	where
		attribute in ('lead', 'org', 'supportstaffid', 'statusstaffid', 'memberid')
) , nameshift as
(
select 
	displaytextranked.*
	, lastname
	, firstname
from
	displaytextranked
	inner join rankednames on displaytextranked.rank = rankednames.rank
)
update
	displaytext
set
	displaytext = case when nameshift.attribute = 'memberid' then lastname || ', ' || firstname else firstname || ' ' || lastname end 
from
	nameshift
where
	displaytext.attribute = nameshift.attribute and displaytext.id = nameshift.id;


update 
	membersourceprev
set
	memberid = newid
from
	mash m 
where
	membersourceprev.memberid = m.oldid and m.attribute = 'memberid'
;

delete from membersourceprev where not memberid in (select id from displaytext where attribute = 'memberid');

update 
	membersourceprev
set
	branchid = newid
from
	mash m 
where
	membersourceprev.branchid = m.oldid and m.attribute = 'branchid'
;

update 
	membersourceprev
set
	industryid = cast(newid as int)
from
	mash m 
where
	membersourceprev.industryid = cast(m.oldid as int) and m.attribute = 'industryid'
;


update 
	membersourceprev
set
	lead = newid
from
	mash m 
where
	membersourceprev.lead = m.oldid and m.attribute = 'lead'
;


update 
	membersourceprev
set
	org = newid
from
	mash m 
where
	membersourceprev.org = m.oldid and m.attribute = 'org'
;


update 
	membersourceprev
set
	employerid = newid
from
	mash m 
where
	membersourceprev.employerid = m.oldid and m.attribute = 'employerid'
;

update 
	membersourceprev
set
	hostemployerid = newid
from
	mash m 
where
	membersourceprev.hostemployerid = m.oldid and m.attribute = 'hostemployerid'
;


update 
	membersourceprev
set
	companyid = newid
from
	mash m 
where
	membersourceprev.companyid = m.oldid and m.attribute = 'companyid'
;


update 
	membersourceprev
set
	supportstaffid = newid
from
	mash m 
where
	membersourceprev.supportstaffid = m.oldid and m.attribute = 'supportstaffid'
;

update 
	membersourceprev
set
	areaid = newid
from
	mash m 
where
	membersourceprev.areaid = m.oldid and m.attribute = 'areaid'
;

update 
	membersourceprev
set
	nuwelectorate = newid
from
	mash m 
where
	membersourceprev.nuwelectorate = m.oldid and m.attribute = 'nuwelectorate'
;

update 
	membersourceprev
set
	feegroupid = newid
from
	mash m 
where
	membersourceprev.feegroupid = m.oldid and m.attribute = 'feegroupid'
;


update 
	membersourceprev
set
	statusstaffid = newid
from
	mash m 
where
	membersourceprev.statusstaffid = m.oldid and m.attribute = 'statusstaffid'
;


with names as
(	
	select
		substr(olddisplaytext, 0,strpos(olddisplaytext, ',')) lastname
		, substr(olddisplaytext, strpos(olddisplaytext, ',')+2, length(olddisplaytext) - strpos(olddisplaytext, ',')-1) firstname
	from
		mash 
	where
		attribute = 'memberid'
)
, lastnames as 
(
select 
	lastname, rank() over (order by random())
from 
	(select distinct lastname from names) names
where
	not lastname is null and length(lastname) > 2
	and not lastname in ('0..', '123213')
limit 500
)
, firstnames as 
(
select 
	firstname, rank() over (order by random())
from 
	(select distinct firstname from names) names
where
	not firstname is null and length(firstname) > 2
limit 500
)
, mixednames as 
(
select 
	firstname
	, lastname
	
from
	firstnames
	inner join lastnames on firstnames.rank = lastnames.rank and firstnames.firstname <> lastnames.lastname
)
, rankednames as
(
select 
	firstname
	, lastname
	, rank() over (order by random()) rank
from
	mixednames
)
, displaytextranked as
(
	select
		*
		, mod(rank() over (order by id),500) + 1 rank
	from
		displaytext
	where
		attribute in ('companyid', 'employerid', 'hostemployerid')
) , nameshift as
(
select 
	displaytextranked.*
	, lastname
	, firstname
from
	displaytextranked
	inner join rankednames on displaytextranked.rank = rankednames.rank
)
update
	displaytext
set
	displaytext 
	= case 
		when nameshift.attribute = 'companyid' then firstname || '''s Store' 
		when nameshift.attribute = 'hostemployerid' then lastname || ' Inc' 
		else lastname || ' Pty Ltd' 
		end 
from
	nameshift
where
	displaytext.attribute = nameshift.attribute and displaytext.id = nameshift.id;

update employer set companyname = displaytext from displaytext where employer.companyid = displaytext.id and attribute = 'employerid';

update 
	employer
set 
	payrollcontactdetail = 
	case when random() * 10 < 5 then 'Mr' else 'Ms' end || ' ' || substr(companyname, 0,strpos(companyname, ' ')) 

	|| '  Direct: 0' 
	|| cast(random() * 2 / 1  +2 as char(1))
	|| ' ' 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| ' '
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 

	|| '   Mobile: 04' 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| ' ' 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| ' '
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| '   Email: payroll@' 
	|| lower(substr(companyname, 0,strpos(companyname, ' ')) )
	|| '.com.au'

where
	not payrollcontactdetail is null
	or random() * 10 < 5;


update 
	membersourceprev
set 
	contactdetail = 

	'  Home: 0' 
	|| cast(random() * 2 / 1  +2 as char(1))
	|| ' ' 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| ' '
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 

	|| '   Mobile: 04' 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| ' ' 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| ' '
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| cast(random() * 9 / 1  +1 as char(1)) 
	|| '   Email: ' 
	|| (select lower(replace(displaytext,', ', '') ) from displaytext where attribute = 'memberid' and id = memberid) 
	|| '@hotmail.com' 

where
	not contactdetail is null;

update
        membersourceprev
set
        followupnotes =
        '01/01/2012 njones: called payroll, on leave'
where
        not followupnotes is null;

drop table areastaff;
drop table displaytextstaging;
drop table employerstaging;
drop table industryfix;
drop table log;
drop table memberfacthelper cascade;
drop table memberfacthelper1;
drop table memberfacthelper2;
drop table memberfacthelper3;

drop table memberfacthelper4_staging;
drop table memberfacthelperpaying;
drop table memberfacthelperpaying2;
drop table memberfacthelperpaying2_backup;
drop table membersource cascade;
drop table missingchange;
drop table missingchangetranslation;
drop table redundantchanges;
drop table statuschangestaff;
drop table statuschangestafftrans;
drop table transactionchanges;
drop table transactionfactbackup;
drop table transactionsource;
drop table transactionsourceprev;
drop table transactionsourceprev_backup;

drop table employerbackup;
drop table memberfacthelper4;

drop function insertchange() cascade;
drop function insertmemberfact() cascade;
drop function inserttransactionfact() cascade;
drop function last_import() cascade;
drop function updatedisplaytext() cascade;
drop function updateemployer() cascade;
drop function insertmemberchangefromlastchange() cascade;

drop view lastchange;
drop view memberchangehelper;

drop table displaytext_anonymisedb;
drop table transactionfact_anonymisedb;
drop table employer_anonymisedb;
drop table mash;

