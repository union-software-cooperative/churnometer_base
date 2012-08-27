# Base class for services that provide autocomplete data to clients.
class ServiceAutocomplete
  def initialize(db, param_hash)
    @db = db
  end

  def present_db_result(db_result)
    db_result_to_json(db_result)
  end

  def max_results
    50
  end

  def execute
    db_result = @db.ex(@query)

    result = []

    db_result.each do |row_hash|
      result << db_hash_to_json_hash(row_hash)

      break if result.length == max_results()
    end

    JSON[result]
  end

protected
  def db_hash_to_json_hash(db_row_hash)
    result = {}

    json_to_db_column_mapping().each do |json_column, db_column|
      db_value = db_row_hash[db_column]

      if db_value.nil?
        raise "Database column '#{db_column}' for json result column '#{json_column}' wasn't returned in the query result."
      end

      result[json_column] = db_value
    end

    result
  end

  def json_to_db_column_mapping
  end
end

