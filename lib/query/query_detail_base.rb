require './lib/query/query_filter'

# Abstract base class containing common functionality for the family of Detail queries.
class QueryDetailBase < QueryFilter
  def initialize(churn_db, header1, filter_column, filter_terms)
    super(churn_db, filter_terms)
    @header1 = header1
    @filter_column = filter_column
  end

  # Returns a map of filter column names to sql 'where' clause text, defining the clause to be used 
  # when the filter column is supplied to the object.
  def self.filter_column_to_where_clause
    {}
  end
end
