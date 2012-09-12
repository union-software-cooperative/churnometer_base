require './lib/churn_db'

class Query
  def initialize(churn_db)
    @churn_db = churn_db
  end

  def execute
    @churn_db.ex(query_string())
  end

protected
  def query_string
    raise 'Provide implementation.'
  end
end

