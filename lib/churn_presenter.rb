require './lib/settings.rb'
require './lib/churn_presenters/helpers.rb'

class ChurnPresenter
  
  attr_reader :transfers
  attr_reader :target
  attr_reader :form
  attr_reader :tables
  attr_reader :graph
  attr_reader :diags
  attr_accessor :warnings
  
  include Enumerable
  include Settings
  include ChurnPresenter_Helpers
  
  def initialize(app, request)
    @app = app
    @request = request
    
    @warnings = @request.warnings
    @transfers = ChurnPresenter_Transfers.new app, request
    @diags = ChurnPresenter_Diags.new request, @transfers.getmath_transfers?

    @form = ChurnPresenter_Form.new(
      app,
			request,
      request_group_dimensions()
    )

    @target = ChurnPresenter_Target.new(app, request) if (@request.auth.leader? || @request.auth.lead?) && request.type == :summary && !@request.data_entry_view?
    @graph = ChurnPresenter_Graph.new(app, request)
    @graph = nil unless (@graph.line? || @graph.waterfall?)
    @tables = ChurnPresenter_Tables.new(app, request) if has_data?
    @tables ||= {}
    
    if !has_data?
      @warnings += 'WARNING:  No data found'
    end
    
    if transfers.exists?
      @warnings += 'WARNING:  There are transfers during this period that may influence the results.  See the transfer tab below. <br />'
    end
    
    if @request.data_entry_view?
      @warnings += 'WARNING:  When exploring data entry only stats about database changes are shown (this view is only available to leadership).'
    end
    # if @request.cache_hit
    #       @warnings += "WARNING: This data has been loaded from cache <br/>"
    #     end
    #     
    #     if ChurnDBDiskCache.cache_status != ""
    #       @warnings += "WARNING: #{ChurnDBDiskCache.cache_status} <br/>"
    #     end
      
  end

  # Properties
  
  # Dimensions applicable to the request.
  def request_group_dimensions
    @request_group_dimensions ||=
      @app.groupby_display_dimensions(@request.auth.leader?, @request.auth.admin?)
  end

  # Mappings from user dimension column names to descriptions
  def request_group_names
    if @request_group_names.nil?
      @request_group_names = {}
      request_group_dimensions().each do |dimension|
        @request_group_names[dimension.id] = dimension.name
      end
    end
    
    @request_group_names
  end

  def has_data?
    @request.data && @request.data.count > 0
  end

  # Summary Display Methods
  def data
    @request.data
  end
  
  def tabs
    result = Hash.new
    
    if !@graph.nil? 
      result['graph'] = 'Graph'
    end
    
    if !@tables.nil?
        @tables.each do | table|
          result[table.id] = table.name
        end
    end
    
    if @transfers.exists?
        result['transfers'] = 'Transfers'
    end
    
    result['diags'] = 'Diagnostics'
    
    result
  end
 
  def to_excel
    excel(data)
  end
 
end
