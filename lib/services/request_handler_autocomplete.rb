require './lib/churn_db'
require 'json'

class ServiceRequestHandlerAutocomplete
  def initialize(churnobyl_app)
    services = { 
      #'branch' => ServiceAutocompleteBranch 
      'company' => ServiceAutocompleteCompany 
    }

    churnobyl_app.get "/autocomplete/:handler_name" do |handler_name|
      service_class = services[handler_name]
      if service_class.nil?
        "No autocomplete handler for '#{handler_name}'"
      else
        service = service_class.new(params)
        service.execute(ChurnDB.new)
      end
    end
  end
end

