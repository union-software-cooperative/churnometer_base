require './lib/services/autocomplete'

# Classes of autocomplete services that query the "displaytext" table
class ServiceAutocompleteDisplaytext < ServiceAutocomplete
  def initialize(db, param_hash)
    super

    attribute = param_hash['attribute']
    search = param_hash['term']

    raise "No attribute supplied." if attribute.nil?
    raise "No search parameter supplied." if search.nil?

    @query = sql_text(db, attribute, search)
  end

protected
  def json_to_db_column_mapping
    {
      'id' => 'id',
      'label' => 'dropdown',
      'value' => 'displaytext'
    }
  end

  def sql_text(db, attribute, search_string)
    # tokenise search string
    search_array = search_string.split(' ')
    
    where_clause = ""
    search_array.each do | item |
      if (!where_clause.empty?) 
        where_clause += ' AND '
      end
      where_clause += "(lower(displaytext || ' (' || id || ')') like #{db.db.quote('%'+item+'%')})"
    end 
    
    if (where_clause.empty?) 
      where_clause = ' 1=1 '
    end
    
    "select id, displaytext, displaytext || ' (' || id || ')' as dropdown from displaytext where attribute = #{db.db.quote(attribute)} and (#{where_clause}) order by displaytext"
  end
end

