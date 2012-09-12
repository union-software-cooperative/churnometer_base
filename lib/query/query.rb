require './lib/churn_db'

class Query
  def initialize(churn_db)
    @churn_db = churn_db
  end

  def execute
    @churn_db.ex(query_string())
  end

protected
  # Returns the object representing the actual database (not the ChurnDB abstraction.)
  def db
    @churn_db.db
  end

  def query_string
    raise 'Provide implementation.'
  end
end

