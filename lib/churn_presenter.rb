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
  
  def initialize(request)
    @request = request
    
    @warnings = @request.warnings
    @transfers = ChurnPresenter_Transfers.new request
    @diags = ChurnPresenter_Diags.new request, @transfers.getmath_transfers?
    @form = ChurnPresenter_Form.new(request, request_group_names())
    @target = ChurnPresenter_Target.new request if (@request.auth.leader? || @request.auth.lead?) && request.type == :summary && !@request.data_entry_view?
    @graph = ChurnPresenter_Graph.new request
    @graph = nil unless (@graph.line? || @graph.waterfall?)
    @tables = ChurnPresenter_Tables.new request if has_data?
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

  # An array of group names applicable to the current request.
  def request_group_names
    @group_names ||= group_names(@request.auth.leader?, @request.auth.admin?)
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
