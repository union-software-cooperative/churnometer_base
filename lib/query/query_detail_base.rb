require './lib/query/query_filter'

# Abstract base class containing common functionality for the family of Detail queries.
class QueryDetailBase < QueryFilter
  def initialize(app, churn_db, groupby_dimension, filter_column, filter_terms)
    super(app, churn_db, filter_terms)
    @groupby_dimension = groupby_dimension
    @filter_column = filter_column
  end

  # Returns a map of filter column names to sql 'where' clause text, defining the clause to be used 
  # when the filter column is supplied to the object.
  def self.filter_column_to_where_clause
    {}
  end

  def where_clause_for_filter_column(filter_column)
    clause = self.class.filter_column_to_where_clause[filter_column]

    if clause.nil?
      raise "Invalid filter column '#{filter_column}'"
    end

    clause
  end
end
