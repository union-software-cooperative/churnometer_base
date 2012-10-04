require './lib/query/query_detail_base'

class QueryDetailStatic < QueryDetailBase
  # site_date may be nil.
  # groupby_dimension: A DimensionUser instance.
  def initialize(churn_db, groupby_dimension, filter_column, member_date, site_date, filter_terms)
    super(churn_db, groupby_dimension, filter_column, filter_terms)
    @site_date = site_date
    @member_date = member_date
  end

  def self.filter_column_to_where_clause
    {
      '' => '', # empty filter column
      'paying' => 'where c.paying<>0',
      'a1p' => 'where c.a1p<>0',
      'stopped' => 'where c.stopped<>0',
      'other' => 'where c.other<>0'
    }
  end

  def query_string
    header1 = @groupby_dimension.column_base_name

    filter = 
      if @site_date.nil?
        filter_terms()
      else
        modified_filter = QueryFilterTerms.new

        site_query = QuerySitesAtDate.new(@churn_db, @site_date, filter_terms())
        site_results = site_query.execute

        if site_results.num_tuples == 0
          modified_filter.append('companyid', 'none', false)
        else
          site_results.each do |record| 
          	modified_filter.append('companyid', record['companyid'], false)
        	end
        end

        # dbeswick: note: unlike other queries, detail_static doesn't keep the 'status' values in the
        # siteconstraint-modified filter.

        modified_filter
      end

    db = @churn_db.db

sql = <<-EOS	
	with lastchange as
	(
		-- finds all changes matching user criteria
		select 
			max(changeid) changeid
		from 
			memberfact
		where
			changedate <= #{db.sql_date(@member_date)} -- we need to count every value since Churnobyls start to determine start_count.  But everything after enddate can be ignored.
		group by 
			memberid
			
	)
	, userselections as 
	(
		select
			*
		from
			#{db.quote_db(@source)}
		where
			changeid in (select changeid from lastchange)
			and net = 1 /* after change not before */
			#{sql_for_filter_terms(filter, true)}
	)
	, counts as
	(
		-- sum changes, if status doesnt change, then the change is a transfer
		select 
			c.memberid
			, c.changeid::bigint	
			, case when coalesce(#{db.quote_db(header1)}::varchar(50),'') = '' then 'unassigned' else #{db.quote_db(header1)}::varchar(50) end row_header
			, case when coalesce(status, '') = '1' then 1 else 0 end::bigint paying
			, case when coalesce(status, '') = '14' then 1 else 0 end::bigint a1p
			, case when coalesce(status, '') = '11' then 1 else 0 end::bigint stopped
			, case when not (coalesce(status, '') = '1' or coalesce(status, '') = '14') then 1 else 0 end::bigint other
		from 
			userselections c			
	)
	select
		c.memberid
		, c.changeid
		, coalesce(d1.displaytext, c.row_header)::varchar(50) row_header -- c.row_header
		, c.row_header::varchar(20) row_header_id
		, c.paying
		, c.a1p
		, c.stopped
		, c.other
	from
		counts c
		left join displaytext d1 on d1.attribute = #{db.quote(header1)} and d1.id = c.row_header
	#{self.class.filter_column_to_where_clause[@filter_column]}
	order by
		c.row_header asc
EOS

		sql
  end
end
