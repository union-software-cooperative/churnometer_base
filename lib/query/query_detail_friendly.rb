require './lib/query/query_detail'

class QueryDetailFriendly < QueryDetail
  def query_string
#CREATE OR REPLACE FUNCTION detail_friendly(IN sourcetable text, IN header1 text, IN filter_column text, IN start_date timestamp without time zone, IN end_date timestamp without time zone, IN with_trans boolean, IN site_constrain text, IN selection xml, OUT memberid character varying, OUT row_header character varying, OUT a1p_real_gain numeric, OUT a1p_newjoin numeric, OUT a1p_rejoin numeric, OUT a1p_real_loss numeric, OUT a1p_to_paying numeric, OUT a1p_to_other numeric, OUT a1p_other_gain numeric, OUT a1p_other_loss numeric, OUT paying_real_gain numeric, OUT paying_real_loss numeric, OUT paying_real_net numeric, OUT paying_other_gain numeric, OUT paying_other_loss numeric, OUT other_gain numeric, OUT other_loss numeric, OUT posted numeric, OUT unposted numeric, OUT changedate date, OUT member text, OUT oldstatus text, OUT newstatus text, OUT currentstatus text, OUT oldcompany text, OUT newcompany text, OUT currentcompany text, OUT oldorg text, OUT neworg text, OUT currentorg text, OUT oldlead text, OUT newlead text, OUT currentlead text, OUT oldstate text, OUT newstate text, OUT currentstate text, OUT oldbranch text, OUT newbranch text, OUT currentbranch text, OUT oldnuwelectorate text, OUT newnuwelectorate text, OUT currentnuwelectorate text, OUT oldindustry text, OUT newindustry text, OUT currentindustry text, OUT oldarea text, OUT newarea text, OUT currentarea text, OUT olddel text, OUT newdel text, OUT currentdel text, OUT oldhsr text, OUT newhsr text, OUT currenthsr text, OUT oldfeegroup text, OUT newfeegroup text, OUT currentfeegroup text, OUT oldemployer text, OUT newemployer text, OUT currentemployer text, OUT contactdetail text, OUT followupnotes text, OUT paymenttypeid text, OUT lateness text, OUT payrollcontactdetail text)
sql = <<-EOS
with detail as  
(
	#{super}
)
, wherearetheynow as
(
	select
	c.memberid
	, d2.displaytext AS currentstatus
	, d16.displaytext AS currentcompany
	, coalesce(d12.displaytext, c.neworg::varchar(50)) as currentorg
	, coalesce(d10.displaytext, c.newlead::varchar(50)) as currentlead
	, coalesce(d19.displaytext, c.newstate::varchar(50)) as currentstate
	, d4.displaytext AS currentbranch
	, coalesce(d8.displaytext, c.newnuwelectorate::varchar(50)) as currentelectorate
	, d6.displaytext AS currentindustry
	, coalesce(d14.displaytext, c.newareaid::varchar(50)) as currentarea
	, coalesce(d25.displaytext, c.newdel::varchar(50)) as currentdel
	, coalesce(d27.displaytext, c.newhsr::varchar(50)) as currenthsr
	, coalesce(d29.displaytext, c.newfeegroupid::varchar(50)) as currentfeegroup
	, coalesce(d30.displaytext, c.newemployerid::varchar(50)) as currentemployer
	
	from 
		memberfact c
		LEFT JOIN displaytext d2 ON d2.attribute::text = 'status'::text AND c.newstatus::character varying(20)::text = d2.id::text
		LEFT JOIN displaytext d4 ON d4.attribute::text = 'branchid'::text AND c.newbranchid::character varying(20)::text = d4.id::text
		LEFT JOIN displaytext d6 ON d6.attribute::text = 'industryid'::text AND c.newindustryid::character varying(20)::text = d6.id::text
		LEFT JOIN displaytext d8 ON d8.attribute::text = 'nuwelectorate'::text AND c.newnuwelectorate::character varying(20)::text = d8.id::text
		LEFT JOIN displaytext d10 ON d10.attribute::text = 'lead'::text AND c.newlead::character varying(20)::text = d10.id::text
		LEFT JOIN displaytext d12 ON d12.attribute::text = 'org'::text AND c.neworg::character varying(20)::text = d12.id::text
		LEFT JOIN displaytext d14 ON d14.attribute::text = 'areaid'::text AND c.newareaid::character varying(20)::text = d14.id::text
		LEFT JOIN displaytext d16 ON d16.attribute::text = 'companyid'::text AND c.newcompanyid::character varying(20)::text = d16.id::text
		LEFT JOIN displaytext d17 ON d17.attribute::text = 'memberid'::text AND c.memberid::character varying(20)::text = d17.id::text
		LEFT JOIN displaytext d19 ON d19.attribute::text = 'state'::text AND c.newstate::character varying(20)::text = d19.id::text
		LEFT JOIN displaytext d25 ON d25.attribute::text = 'del'::text AND c.newdel::character varying(20)::text = d25.id::text
		LEFT JOIN displaytext d27 ON d27.attribute::text = 'hsr'::text AND c.newhsr::character varying(20)::text = d27.id::text
		LEFT JOIN displaytext d29 ON d29.attribute::text = 'feegroupid'::text AND c.newfeegroupid::character varying(20)::text = d29.id::text
		LEFT JOIN displaytext d30 ON d30.attribute::text = 'employerid'::text AND c.newemployerid::character varying(20)::text = d30.id::text
		
	where 
		c.changeid in (select max(changeid) from memberfact m where m.memberid in (select detail.memberid from detail) group by m.memberid)
)
 SELECT
	d.memberid
	, d.row_header
	, sum(d.a1p_real_gain) a1p_real_gain
	, sum(d.a1p_newjoin) a1p_newjoin
	, sum(d.a1p_rejoin) a1p_rejoin
	, sum(d.a1p_real_loss) a1p_real_loss
	, sum(d.a1p_to_paying) a1p_to_paying
	, sum(d.a1p_to_other) a1p_to_other
	, sum(d.a1p_other_gain) a1p_other_gain
	, sum(d.a1p_other_loss) a1p_other_loss
	, sum(d.paying_real_gain) paying_real_gain
	, sum(d.paying_real_loss) paying_real_loss
	, sum(d.paying_real_net) paying_real_net
	, sum(d.paying_other_gain) paying_other_gain
	, sum(d.paying_other_loss) paying_other_loss
	, sum(d.other_gain) other_gain
	, sum(d.other_loss) other_loss
	, sum(d.posted::numeric) posted
	, sum(d.unposted::numeric) unposted
	, c.changedate::date AS changedate
	, ((coalesce(d17.displaytext,'No Name') || ' ('::text) || c.memberid::text) || ')'::text AS member
	, d1.displaytext AS oldstatus
	, d2.displaytext AS newstatus
	, n.currentstatus
	, d15.displaytext AS oldcompany
	, d16.displaytext AS newcompany
	, n.currentcompany
	, coalesce(d11.displaytext, c.oldorg::varchar(50)) as oldorg
	, coalesce(d12.displaytext, c.neworg::varchar(50)) as neworg
	, n.currentorg
	, coalesce(d9.displaytext, c.oldlead::varchar(50)) as oldlead
	, coalesce(d10.displaytext, c.newlead::varchar(50)) as newlead
	, n.currentlead
	, coalesce(d18.displaytext, c.oldstate::varchar(50)) as oldstate
	, coalesce(d19.displaytext, c.newstate::varchar(50)) as newstate
	, n.currentstate
	, d3.displaytext AS oldbranch
	, d4.displaytext AS newbranch
	, n.currentbranch
	, coalesce(d7.displaytext, c.oldnuwelectorate::varchar(50)) as oldnuwelectorate
	, coalesce(d8.displaytext, c.newnuwelectorate::varchar(50)) as newnuwelectorate
	, n.currentelectorate as currentnuwelectorate
	, d5.displaytext AS oldindustry
	, d6.displaytext AS newindustry
	, n.currentindustry
	, coalesce(d13.displaytext, c.oldareaid::varchar(50)) as oldarea
	, coalesce(d14.displaytext, c.newareaid::varchar(50)) as newarea
	, n.currentarea
	, coalesce(d24.displaytext, c.olddel::varchar(50)) as olddel
	, coalesce(d25.displaytext, c.newdel::varchar(50)) as newdel
	, n.currentdel
	, coalesce(d26.displaytext, c.oldhsr::varchar(50)) as oldhsr
	, coalesce(d27.displaytext, c.newhsr::varchar(50)) as newhsr
	, n.currenthsr
	, coalesce(d28.displaytext, c.oldfeegroupid::varchar(50)) as oldfeegroup
	, coalesce(d29.displaytext, c.newfeegroupid::varchar(50)) as newfeegroup
	, n.currentfeegroup
	, coalesce(d30.displaytext, c.oldemployerid::varchar(50))::text as oldemployer
	, coalesce(d31.displaytext, c.newemployerid::varchar(50))::text as newemployer
	, n.currentemployer
	, m.contactdetail::text
	, m.followupnotes::text
	, m.paymenttypeid::text
	, e.lateness::text
	, e.payrollcontactdetail::text
	
   FROM detail d
   JOIN memberfact c ON d.changeid = c.changeid
   LEFT JOIN wherearetheynow n on c.memberid = n.memberid
   LEFT JOIN displaytext d1 ON d1.attribute::text = 'status'::text AND c.oldstatus::character varying(20)::text = d1.id::text
   LEFT JOIN displaytext d2 ON d2.attribute::text = 'status'::text AND c.newstatus::character varying(20)::text = d2.id::text
   LEFT JOIN displaytext d3 ON d3.attribute::text = 'branchid'::text AND c.oldbranchid::character varying(20)::text = d3.id::text
   LEFT JOIN displaytext d4 ON d4.attribute::text = 'branchid'::text AND c.newbranchid::character varying(20)::text = d4.id::text
   LEFT JOIN displaytext d5 ON d5.attribute::text = 'industryid'::text AND c.oldindustryid::character varying(20)::text = d5.id::text
   LEFT JOIN displaytext d6 ON d6.attribute::text = 'industryid'::text AND c.newindustryid::character varying(20)::text = d6.id::text
   LEFT JOIN displaytext d7 ON d7.attribute::text = 'nuwelectorate'::text AND c.oldnuwelectorate::character varying(20)::text = d7.id::text
   LEFT JOIN displaytext d8 ON d8.attribute::text = 'nuwelectorate'::text AND c.newnuwelectorate::character varying(20)::text = d8.id::text
   LEFT JOIN displaytext d9 ON d9.attribute::text = 'lead'::text AND c.oldlead::character varying(20)::text = d9.id::text
   LEFT JOIN displaytext d10 ON d10.attribute::text = 'lead'::text AND c.newlead::character varying(20)::text = d10.id::text
   LEFT JOIN displaytext d11 ON d11.attribute::text = 'org'::text AND c.oldorg::character varying(20)::text = d11.id::text
   LEFT JOIN displaytext d12 ON d12.attribute::text = 'org'::text AND c.neworg::character varying(20)::text = d12.id::text
   LEFT JOIN displaytext d13 ON d13.attribute::text = 'areaid'::text AND c.oldareaid::character varying(20)::text = d13.id::text
   LEFT JOIN displaytext d14 ON d14.attribute::text = 'areaid'::text AND c.newareaid::character varying(20)::text = d14.id::text
   LEFT JOIN displaytext d15 ON d15.attribute::text = 'companyid'::text AND c.oldcompanyid::character varying(20)::text = d15.id::text
   LEFT JOIN displaytext d16 ON d16.attribute::text = 'companyid'::text AND c.newcompanyid::character varying(20)::text = d16.id::text
   LEFT JOIN displaytext d17 ON d17.attribute::text = 'memberid'::text AND c.memberid::character varying(20)::text = d17.id::text
   LEFT JOIN displaytext d18 ON d18.attribute::text = 'state'::text AND c.oldstate::character varying(20)::text = d18.id::text
   LEFT JOIN displaytext d19 ON d19.attribute::text = 'state'::text AND c.newstate::character varying(20)::text = d19.id::text
   LEFT JOIN displaytext d24 ON d24.attribute::text = 'del'::text AND c.olddel::character varying(20)::text = d24.id::text
   LEFT JOIN displaytext d25 ON d25.attribute::text = 'del'::text AND c.newdel::character varying(20)::text = d25.id::text
   LEFT JOIN displaytext d26 ON d26.attribute::text = 'hsr'::text AND c.oldhsr::character varying(20)::text = d26.id::text
   LEFT JOIN displaytext d27 ON d27.attribute::text = 'hsr'::text AND c.newhsr::character varying(20)::text = d27.id::text
   LEFT JOIN displaytext d28 ON d28.attribute::text = 'feegroupid'::text AND c.oldfeegroupid::character varying(20)::text = d28.id::text
   LEFT JOIN displaytext d29 ON d29.attribute::text = 'feegroupid'::text AND c.newfeegroupid::character varying(20)::text = d29.id::text
   LEFT JOIN displaytext d30 ON d30.attribute::text = 'employerid'::text AND c.oldemployerid::character varying(20)::text = d30.id::text
   LEFT JOIN displaytext d31 ON d31.attribute::text = 'employerid'::text AND c.newemployerid::character varying(20)::text = d31.id::text
   LEFT JOIN employer e on c.newemployerid = e.companyid
   LEFT JOIN membersourceprev  m on c.memberid = m.memberid
	

group by 
	d.row_header
	, c.changedate::date 
	, d.memberid
	, ((d17.displaytext || ' ('::text) || c.memberid::text) || ')'::text
	, d1.displaytext 
	, d2.displaytext
	, d3.displaytext
	, d4.displaytext
	, d5.displaytext
	, d6.displaytext
	, d7.displaytext
	, d8.displaytext
	, d9.displaytext
	, d10.displaytext
	, d11.displaytext
	, d12.displaytext
	, d13.displaytext
	, d14.displaytext
	, d17.displaytext
	, d24.displaytext
	, d25.displaytext
	, d26.displaytext
	, d27.displaytext
	, d28.displaytext
	, d29.displaytext
	, d18.displaytext
	, d19.displaytext
	, c.memberid
	, c.oldlead
	, c.newlead
	, n.currentlead
	, c.oldorg
	, c.neworg
	, n.currentorg
	, d13.displaytext 
	, d14.displaytext
	, n.currentarea
	, d15.displaytext 
	, d16.displaytext 
	, n.currentcompany
	, c.olddel
	, c.newdel
	, n.currentdel
	, c.oldhsr
	, c.newhsr
	, n.currenthsr
	, c.oldnuwelectorate
	, c.newnuwelectorate
	, n.currentelectorate
	, c.oldareaid
	, c.newareaid
	, c.oldstate
	, c.newstate
	, n.currentstate
	, c.oldfeegroupid
	, c.newfeegroupid
	, n.currentfeegroup
	, n.currentbranch
	, n.currentindustry
	, n.currentstatus
	, m.contactdetail
	, n.currentemployer
	, c.oldemployerid
	, c.newemployerid
	, m.contactdetail
	, m.followupnotes
	, m.paymenttypeid
	, e.lateness
	, e.payrollcontactdetail
	, d30.displaytext
	, d31.displaytext
EOS
  end
end
