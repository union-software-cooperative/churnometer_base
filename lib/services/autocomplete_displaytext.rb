require './lib/services/autocomplete'

# Classes of autocomplete services that query the "displaytext" table
class ServiceAutocompleteDisplaytext < ServiceAutocomplete
protected
  def json_to_db_column_mapping
    {
      'id' => 'id',
      'label' => 'displaytext',
      'value' => 'displaytext'
    }
  end

  def sql_text(search_string)
    "select id, displaytext from displaytext where attribute = \'#{sql_attribute()}\' and displaytext ilike \'%#{search_string.gsub('\'','\'\'')}%\' order by displaytext"
  end
end

