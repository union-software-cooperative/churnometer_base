require './lib/config'

# A collection of UserDataTable instances.
class UserDataTables
  include Enumerable

  def initialize
    @id_to_data_table = {}
  end

  def from_config_element(config_element)
    config_element.value.each do |table_id, hash_element|
      @id_to_data_table[table_id] = UserDataTable.from_config_element(table_id.downcase, hash_element)
    end

    self
  end

  def [](id)
    @id_to_data_table[id]
  end

  def each(&block)
    @id_to_data_table.values.each(&block)
  end
end

# Defines how data returned from database queries should be presented to the user in table form.
# Different UserRole instances may make use of different data table definitions to include or omit 
# query result columns for the roles they define, for example, showing financial information only to
# the 'leader' role.
class UserDataTable
  attr_reader :id

  # The name of the data table as displayed to the user. Currently used as the title for tabs in the
  # Churnometer main interface.
  attr_reader :display_name

  # A list of column names that should be applied to the returned data. The valid column names are 
  # determined by the query that this UserDataTable is expected to apply to (summary or detail query.)
  attr_reader :column_names

  def self.from_config_element(id, config_element)
    config_element.instance_eval do
      ensure_kindof(Hash)
      ensure_hashkey('display_name')
      ensure_hashkey('query_columns')
    end

    query_columns = config_element['query_columns'].value.collect do |array_element|
      array_element.ensure_kindof(String)
      array_element.value
    end

    new(id, config_element['display_name'].value, query_columns)
  end

  def initialize(id, display_name, column_names)
    @id = id
    @display_name = display_name
    @column_names = column_names
  end
end
