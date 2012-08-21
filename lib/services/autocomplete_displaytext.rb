require './lib/services/autocomplete'

# Classes of autocomplete services that query the "displaytext" table
class ServiceAutocompleteDisplaytext < ServiceAutocomplete
  def initialize(db, param_hash)
    super

    attribute = param_hash['attribute']
    search = param_hash['search']

    raise "No attribute supplied." if attribute.nil?
    raise "No search parameter supplied." if search.nil?

    @query = sql_text(db, attribute, search)
  end

protected
  def json_to_db_column_mapping
    {
      'id' => 'id',
      'label' => 'displaytext',
      'value' => 'displaytext'
    }
  end

  def sql_text(db, attribute, search_string)
    "select id, displaytext from displaytext where attribute = #{db.db.quote(attribute)} and displaytext ilike #{db.db.quote('%'+search_string+'%')} order by displaytext"
  end
end

