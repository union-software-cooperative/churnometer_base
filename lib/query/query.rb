require './lib/churn_db'

class Query
  def initialize(churn_db)
    @churn_db = churn_db
  end

  def execute
    @churn_db.ex(query_string())
  end

protected
  def sql_array(array, type)
    result = "ARRAY[#{array.join(', ')}]"
    result << "::#{type}[]" if type
    result
  end

  def sql_datetime(time)
    "'#{time.strftime('%Y-%m-%d')}'"
  end

  def query_string
    raise 'Provide implementation.'
  end
end

