require './lib/churn_db'
require 'json'

class ServiceRequestHandlerAutocomplete
  def initialize(churnobyl_app_class)
    services = { 
      'displaytext' => ServiceAutocompleteDisplaytext
    }

    churnobyl_app_class.get "/services/autocomplete/:handler_name" do |handler_name|
      content_type :json

      service_class = services[handler_name]
      if service_class.nil?
        "No autocomplete handler for '#{handler_name}'"
      else
        service = service_class.new(churn_db(), app(), params)
        service.execute
      end
    end
    
    churnobyl_app_class.after "/services/autocomplete/:handler_name" do |handler_name|
      @cr.close_db() if !@cr.nil? 
    end
  end
end

