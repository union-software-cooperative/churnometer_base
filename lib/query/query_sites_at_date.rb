require './lib/query/query_filter'

class QuerySitesAtDate < QueryFilter
  def initialize(churn_db, header1, date, filter_terms)
    super(churn_db, '')
    @source = churn_db.fact_table
    @header1 = header1
    @date = date
    @filter_terms = filter_terms
  end

  def query_string
    db = @churn_db.db

    sql = <<-EOS
	with last_change as
	(
		-- get the last change prior to the sample date for each member
		-- this tell us the state of each member at the sample date
		select
			max(changeid) changeid
		from
			#{db.quote_db(@source)}
		where
			changedate <= #{db.sql_date(@date)}
		group by 
			memberid
	)

	, selections as
	(
		-- finds all changes matching user criteria
		select 
			* 
		from
			#{db.quote_db(@source)}
		where
			net = 1
			and changeid in (select changeid from last_change)
			#{sql_for_filter_terms(@filter_terms, true)}
 	)
	select distinct companyid from selections;

EOS

    sql
  end
end
