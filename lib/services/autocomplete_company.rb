require './lib/services/autocomplete_displaytext'

class ServiceAutocompleteCompany < ServiceAutocompleteDisplaytext
  def initialize(param_hash)
    param_hash.each do |key, value|
      @query = 
        case key
        when 'name'; sql_text(value)
        end
      
      break if @query
    end

    raise "Malformed autocomplete request." if @query.nil?
  end

  protected
  def sql_attribute
    "companyid"
  end
end
