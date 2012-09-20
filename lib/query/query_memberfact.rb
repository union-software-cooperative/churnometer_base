require './lib/query/query'

# Describes queries that interact with the 'memberfact' tables.
class QueryMemberfact < Query
  # The name of the 'memberfact' table used as the source of the query.
  attr_reader :source

  def initialize(db)
    super
    @source = db.fact_table
  end
end
