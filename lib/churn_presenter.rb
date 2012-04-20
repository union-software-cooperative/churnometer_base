require './lib/settings.rb'

class ChurnPresenter
  
  attr_reader :transfers
  attr_reader :target
  attr_reader :form
  attr_reader :tables
  attr_reader :graph
  attr_reader :diags
  attr_accessor :warnings
  
  include Enumerable
  include Settings # for to_excel - todo refactor
  
  def initialize(request)
    @request = request
    
    @warnings = @request.warnings
    @form = ChurnPresenter_Form.new request
    @target = ChurnPresenter_Target.new request if (@request.auth.leader? || @request.auth.lead?) && request.type == :summary
    @graph = ChurnPresenter_Graph.new request
    @graph = nil unless (@graph.line? || @graph.waterfall?)
    @tables = ChurnPresenter_Tables.new request if has_data?
    @tables ||= {}
    @transfers = ChurnPresenter_Transfers.new request
    @diags = ChurnPresenter_Diags.new request, @transfers.getmath_transfers?
    
    if !has_data?
      @warnings += 'WARNING:  No data found'
    end
    
    if transfers.exists?
      @warnings += 'WARNING:  There are transfers during this period that may influence the results.  See the transfer tab below. <br />'
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
    ChurnPresenter_Helpers::excel(data)
  end
 
end
