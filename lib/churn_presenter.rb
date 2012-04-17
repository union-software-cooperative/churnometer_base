require './lib/helpers.rb'
require './lib/constants.rb'
require 'spreadsheet'

class ChurnPresenter
  
  attr_reader :transfers
  attr_reader :target
  attr_reader :form
  attr_reader :tables
  attr_reader :graph
  attr_reader :diags
  attr_reader :warnings
  
  include Enumerable
  include Helpers
  include Mappings # for to_excel - todo refactor
  
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
  end

  # Properties
  
  def has_data?
    @request.data && @request.data.count > 0
  end

  # Summary Display Methods
  
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
 
end

module ChurnPresenter_Helpers
  
  include Rack::Utils
  alias_method :h, :escape_html # needed for build_url - refactor
  
  def paying_start_total
    # can't figure out enumerable way to sum this
    # group by is when running totals are shown because you don't want to sum a running start count.
    # so only count the first row for each group (v[0])
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[0]['paying_start_count'].to_i
    end
    t
  end

  def paying_end_total
    # can't figure out enumerable way to sum this
    # group by is when running totals are shown because you don't want to sum a running end count.
    # so only count the last row for each group (v.count-1)
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[v.count-1]['paying_end_count'].to_i
    end
    t
  end
  
  def paying_transfers_total
    t=0
    @request.data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[0]['paying_other_gain'].to_i + v[0]['paying_other_loss'].to_i
    end
    t
  end

  def drill_down_header_link(group, value, next_group)
    # TODO I think this should be somewhere that abstracts filter logic
    build_url ({"#{Filter}[#{group}]" => value, "group_by" => next_group })
  end
  
  def build_url(query_hashes)
    #TODO refactor out params if possible, or put this function somewhere better, with params maybe
    
    # build uri from params - rejecting filters & lock because they need special treatment
    query = @request.params.reject{ |k,v| v.empty? }.reject{ |k, v| k == Filter}.reject{ |k, v| k == "lock"}
    
    # flatten filters, rejecting status - TODO get rid of status
    (@request.params[Filter] || {}).reject{ |k,v| v.empty? }.reject{ |k,v| k == 'status'}.each do |k, v|
      query["#{Filter}[#{k}]"] = v
    end
    
    # flatten lock
    (@request.params["lock"] || {}).reject{ |k,v| v.empty? }.each do |k, v|
      query["lock[#{k}]"] = v
    end
    
    # merge new items
    query.merge! (query_hashes || {})
    
    # remove any empty/blanked-out items
    query = query.reject{ |k,v| v.empty? }
    
    # make uri string
    uri = '/?'
    query.each do |key, value|
      uri += "&#{h key}=#{h value}" 
    end
    
    uri.sub('/?&', '?')
  end
  
end

class ChurnPresenter_Transfers
  
  include Helpers
  include Mappings
  include ChurnPresenter_Helpers
  
  def initialize(request)
    @request = request
  end
  
  def exists?
    # count the transfers, including both in and out
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate'])
    months = Float(end_date - start_date) / 30.34
    
    t=0
    @request.data.each do |row|
      t += row['external_gain'].to_i - row['external_loss'].to_i
    end

    startcnt =  paying_start_total
    endcnt = paying_end_total
    
    threshold = ((startcnt + endcnt)/2 * (MonthlyTransferWarningThreshold * months))
    t > threshold ? true : false
  end
  
  def transfers
    @request.db.get_transfers(@request.params)
  end
  
  def getmath_transfers?
    # count the transfers, including both in and out
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate'])
    months = Float(end_date - start_date) / 30.34
    
    t=0
    @request.data.each do |row|
      t += row['external_gain'].to_i - row['external_loss'].to_i
    end

    startcnt =  paying_start_total
    endcnt = paying_end_total

    threshold = ((startcnt + endcnt)/2 * (MonthlyTransferWarningThreshold * months))
    t > threshold ? true : false
  
    "The system will warn the user and display this tab, when the external transfer total (#{t}) is greater than the external transfer threshold (#{threshold.round(0)} = (average size (#{(startcnt+endcnt)/2} = (#{col_names['paying_start_count']} (#{startcnt}) + #{col_names['paying_end_count']} (#{endcnt}))/2) * MonthlyThreshold (#{(MonthlyTransferWarningThreshold*100).round(1)}%) x months (#{months.round(1)}))).  The rational behind this formula is that 100% of the membership will transfer to growth from development and back every three years (2.8% in and 2.8% out each month). So transfers below this threshold are typical and can be ignored, as opposed to atypical area restructuring of which the user needs warning."
  end
  
  def start_date
    @request.params['startDate']
  end
  
  def end_date
    @request.params['endDate']
  end
  
end

class ChurnPresenter_Form
  
  include Mappings
  
  def initialize(request)
    @request = request
  end
  
  def [](index)
    @request.params[index]
  end
  
  def filters
    if @filters.nil?
      @filters = Array.new
      
      f1 = (@request.params[Filter]).reject{ |column_name, id | id.empty? }
      f1 = f1.reject{ |column_name, id | column_name == 'status' }
      
      if !f1.nil?
        f1.each do |column_name, id|
          i = (Struct.new(:name, :group, :id, :display, :type)).new
          i[:name] = column_name
          i[:group] = group_names[column_name]
          i[:id] = filter_value(id)
          i[:display] = db.get_display_text(column_name, filter_value(id))
          i[:type] = (id[0] == '-' ? "disable" : ( id[0] == '!' ? "invert" : "apply" ))
          @filters << i
        end
      end 
    end
    
    @filters
  end
  
  def row_header_id_list
    @request.data.group_by{ |row| row['row_header1_id'] }.collect{ | rh | rh[0] }.join(",")
  end
  
  private
  
  def db
    @db ||= ChurnDB.new
  end
  
  def filter_value(value)
    value.sub('!','').sub('-','')
  end
  
  
end

class ChurnPresenter_Target
  
  include ChurnPresenter_Helpers
  include Mappings
  
  def initialize(request)
    @request=request
  end
  
  def weeks
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate'])
    
    (Float(end_date - start_date) / 7).round(1)
  end
  
  def growth
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate'])
  
    start_count = paying_start_total
    
    started = 0
    @request.data.each { | row | started += row['paying_real_gain'].to_i }
    
    stopped = 0
    @request.data.each { | row | stopped += row['paying_real_loss'].to_i }
    
    end_count = start_count + stopped + started
    
    start_date == end_date || start_count == 0 ? Float(1/0.0) : Float((((Float(end_count) / Float(start_count)) **  (365.0/(Float(end_date - start_date)))) - 1) * 100).round(1)
  end

  def get_cards_in_growth_target
    
    # the number of people who stopped paying
    stopped = 0
    @request.data.each { | row | stopped -= row['paying_real_loss'].to_i }
    
    # count the people who start paying without giving us a card
    # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
    resume = 0 
    @request.data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 
    
    # count of a1p people who start paying
    conversions = 0
    @request.data.each { | row | conversions -= row['a1p_to_paying'].to_i }
    
    # count the joiners who fail to convert to paying
    failed = 0 
    @request.data.each { | row | failed -= row['a1p_to_other'].to_i }
    
    # count the joiners who fail to convert to paying
    cards = 0 
    @request.data.each { | row | cards += row['a1p_real_gain'].to_i }
    
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate'])
    
    cards_per_week = 0.0
    if start_date != end_date  
      growth = Float((paying_start_total + paying_transfers_total)) * 0.1 / 365 * Float(end_date - start_date) # very crude growth calculation - But I don't think CAGR makes sense, the formula would be # growth = (((10% + 1) ^ (duration/365) * start) - start) 
       
      # METHOD 1.  for every sign up, we only convert some to paying
      # growth = conversions == 0 || cards == 0 ? growth : growth * (cards/conversions) # if we got no conversions or cards, then don't worry about the ratio and just go for cards in - bad bad bad.
      
      # METHOD 2. For every card we get in, there is some that never start paying 10 vs 2.  If we get 20 we'd expect 4 to not start paying.
      # To get the 4 we multiple growth target number failed/cards * target + target 
      # growth += (cards == 0 ? 0 : failed/cards * growth)  
      
      # METHOD 3.  Maybe I'm counting the conversion ratio twice in Method 1 and 2.  
      # The conversion ratio may be already included in the cards we need to hold our ground
      # See + failed in equation below, so I should leave the raw growth figure alone
      # Method 1 and 2 also leave the equation vulnerable to crazy volatility
       
      # to hold our ground we need to recruit the same number as those that stopped, 
      # less those that historically resume paying on their own (these are freebies)
      # plus those that new cards that failed to start paying
      # plus a certain amount to achieve some growth figure.  The growth figure should reflect
      cards_per_week = Float((Float(stopped - resume + failed + growth) / Float(end_date - start_date) * 7 )).round(1) 
    end
    
    cards_per_week
  end

  def get_cards_in_target
    
    # the number of people who stopped paying
    stopped = 0
    @request.data.each { | row | stopped -= row['paying_real_loss'].to_i }
    
    # count the people who start paying without giving us a card
    # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
    resume = 0 
    @request.data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 
    
    # count the joiners who fail to convert to paying
    failed = 0 
    @request.data.each { | row | failed -= row['a1p_to_other'].to_i }
    
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate'])
    
    cards_per_week = 0.0
    if start_date != end_date  
      cards_per_week = Float((Float(stopped - resume + failed) / Float(end_date - start_date) * 7 )).round(1)
    end
    
    cards_per_week
  end

  def getmath_get_cards_in_target

     # the number of people who stopped paying
     stopped = 0
     @request.data.each { | row | stopped -= row['paying_real_loss'].to_i }

     # count the people who start paying without giving us a card
     # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
     resume = 0 
     @request.data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 

     paying_real_gain = 0 
     @request.data.each { | row | paying_real_gain += row['paying_real_gain'].to_i } 
     
     a1p_to_paying = 0 
     @request.data.each { | row | a1p_to_paying += row['a1p_to_paying'].to_i } 
     
     # count the joiners who fail to convert to paying
     failed = 0 
     @request.data.each { | row | failed -= row['a1p_to_other'].to_i }

     start_date = Date.parse(@request.params['startDate'])
     end_date = Date.parse(@request.params['endDate'])

     cards_per_week = 0.0
     weeks = 0
     cards = 0 
     cards_per_week = 0
     if start_date != end_date 
       weeks =  Float(end_date - start_date) / 7
       cards = Float(stopped - resume + failed)
       cards_per_week = Float(cards / weeks ).round(1)
     end

     "#{cards.round(0)} cards needed (#{stopped} #{col_names['paying_real_loss']} + #{failed} #{col_names['a1p_to_other']} - #{resume} resumed paying without a card (#{paying_real_gain} #{col_names['paying_real_gain']} - #{-a1p_to_paying} #{col_names['a1p_to_paying']}) ) / #{weeks.round(1)} weeks = #{cards_per_week}  cards per week"
   end

  def get_cards_in
    
    # the number of people who stopped paying
    cards = 0
    @request.data.each { | row | cards += row['a1p_real_gain'].to_i }
    
    start_date = Date.parse(@request.params['startDate'])
    end_date = Date.parse(@request.params['endDate'])
    
    cards_per_week = 0.0
    if start_date != end_date  
      cards_per_week = Float(((cards) / Float(end_date - start_date) * 7 )).round(1)
    end
    
    cards_per_week
  end
   
end

class ChurnPresenter_Graph
  
  include Helpers
  include Mappings
  include ChurnPresenter_Helpers
  
  def initialize(request)
    @request = request
  end
    
  def series_count
    rows = @request.data.group_by{ |row| row['row_header1'] }.count
  end

  def line?
    series_count <= 30 && @request.params['group_by'] != 'statusstaffid' && @request.params['column'].empty? && @request.params['interval'] != 'none'
  end

  def waterfall?
    cnt =  @request.data.reject{ |row | row["paying_real_gain"] == '0' && row["paying_real_loss"] == '0' }.count
    cnt > 0  && cnt <= 30 && @request.params['group_by'] != 'statusstaffid' && @request.params['column'].empty? && @request.params['interval'] == 'none'
  end
  
  def waterfallItems
    a = Array.new
    @request.data.each do |row|
      i = (Struct.new(:name, :gain, :loss, :link)).new
      i[:name] = row['row_header1']
      i[:gain] = row['paying_real_gain']
      i[:loss] = row['paying_real_loss']
      i[:link] = drill_down_header_link(@request.params['group_by'], row['row_header1_id'], next_group_by[@request.params['group_by']]) 
      a << i
    end
    a
  end
  
  def waterfallTotal
    t = 0;
    @request.data.each do |row|
      t += row['paying_real_gain'].to_i + row['paying_real_loss'].to_i
    end
    t
  end
  
  def periods
    @request.data.group_by{ |row| row['period_header'] }.sort{|a,b| a[0] <=> b[0] }
  end
  
  def pivot
    series = Hash.new
    
    rows = @request.data.group_by{ |row| row['row_header1'] }
    rows.each do | row |
      series[row[0]] = Array.new
      periods.each do | period |
        intersection = row[1].find { | r | r['period_header'] == period[0] }
        if intersection.nil? 
          series[row[0]] << "{ y: null }"
        else
          # assemble point data - url used when user clicks to drill down
          # TODO figure out how to fix this horrible mess
          drilldown_url = build_url({ "startDate" => intersection['period_start'], "endDate" => intersection['period_end'], "interval" => 'none', "#{Filter}[#{@request.params['group_by'] || 'branchid' }]" => "#{intersection['row_header1_id']}", "group_by" => "#{next_group_by[@request.params['group_by']]}" })
          series[row[0]] << "{ y: #{intersection['running_paying_net'] }, id: '#{drilldown_url}' }"
        end
      end
    end
  
    series
  end
  
  def lineCategories
    periods.collect { | k | "'#{k[0]}'"}.join(",") 
  end
  
  def lineSeries
    pivot.collect { | k, v | "{ name: '#{h(k)}', data: [#{v.collect{ | i | i }.join(',')}] }" }.join(",\n") 
  end
  
  def lineHeader
    col_names['row_header1']
  end
  
end

class ChurnPresenter_Table
  attr_reader :id
  attr_reader :name
  attr_reader :type
  attr_reader :columns
  
  include Mappings
  include ChurnPresenter_Helpers
  
  def initialize(request, name, columns)
    @id = name.sub(' ', '').downcase
    @name = name
    @columns = columns.reject{ |c| !request.data[0].include?(c) } #include only columns in both data and column array
    @type = request.type
    @request = request
    @data = request.data
  end
  
  def header
    #@data[ 0].reject{ |k| k.first=='row_header1_id'}
    @columns
  end
  
  def footer
    if @footer.nil? && type==:summary
      @footer = Hash.new
    
      @data.each do |row|
        @columns.each do |column_name|
          value = row[column_name]
          @footer[column_name] ||= 0
          @footer[column_name] = safe_add footer[column_name], value
        end
      end
    end
    
    @footer
  end
  
  def display_header(column_name)
    content = col_names[column_name] || column_name
    
    if bold_col?(column_name)
      "<strong>#{content}</strong>"
    else
      content
    end
  end
  
  def display_cell(column_name, row)
	  	
    if column_name == 'row_header1'
      content = "<a href=\"#{drill_down_header_link(@request.params['group_by'], row['row_header1_id'], next_group_by[@request.params['group_by']]) }\">#{row['row_header1']}</a>"
    elsif column_name == 'period_header'
    #   content = "<a href=\"#{ drill_down_link_interval(row)}\">#{value}</a>"
    # elsif can_detail_cell? column_name, v
    #   content = "<a href=\"#{ detail_cell(row, column_name) }\">#{value}</a>"
    #     elsif can_export_cell? column_name, v
    #   content = "<a href=\"#{ export_cell(row, column_name)}\">#{value}</a>"
    else
       content = row[column_name]
    end
		
		if bold_col?(column_name)
      "<strong>#{content}</strong>"
    else
      content
    end
  end
  
  def display_footer(column_name, total)
    #       totals[column_name] ||= 0
    #       totals[column_name] = safe_add totals[column_name], v
    #       
    #       
    #       <% if bold_col?(column_name) %>
    #               <strong>
    #             <% end %>
    #             <% if !no_total.include?(column_name) %>
    #               <% if can_detail_cell? column_name, total %>
    #           <a href="<%= detail_column(column_name) %>"><%= total %></a>
    # <% elsif can_export_cell? column_name, total %>
    #                 <a href="<%= export_column(column_name) %>"><%= total %></a>
    #               <% else %>
    #                 <%= total %>
    #               <% end %>
    #           <% end %>
    #           <% if bold_col?(column_name) %>
    #               <strong>
    #           <% end %>
    
    if !no_total.include?(column_name)
      if bold_col?(column_name)
        "<strong>#{total}</strong>"
      else
        total
      end
    end
  end
  
  def tooltips
    tips.reject{ |k,v| !@columns.include?(k)}
  end
    
  
  # Wrappers
  def [](index)
    @data[index]
  end

  def each
    @data.each { |row| yield row }
  end

  def to_excel
     book = Spreadsheet::Excel::Workbook.new
     sheet = book.create_worksheet

     # Add header
     @data[0].each_with_index do |hash, x|
       sheet[0, x] = (col_names[hash.first] || hash.first)
     end

     # Add data
     @data.each_with_index do |row, y|
       row.each_with_index do |hash,x|
         if filter_columns.include?(hash.first) 
           sheet[y + 1, x] = hash.last.to_i
         else
             sheet[y + 1, x] = hash.last
         end  
       end
     end

     path = "tmp/data.xls"
     book.write path

     path
   end

  private
  
  def safe_add(a, b)
    if (a =~ /\./) || (b =~ /\./ )
      a.to_f + b.to_f
    else
      a.to_i + b.to_i
    end
  end

end

class ChurnPresenter_Tables
  attr_accessor :tables
  
  include Enumerable
  include Mappings
  
  def initialize(request)
    @request = request
    
    @tables = Array.new
    (@request.type == :summary ? summary_tables : member_tables).each do | name, columns |
      @tables << (ChurnPresenter_Table.new request, name, columns)
    end
  end
  
  # Tables wrappers
  def each
    tables.each { |table| yield table}
  end
  
  def [](index)
    tables.first{ |t| t.name == index }
  end
end

class ChurnPresenter_Diags
  
  attr_reader :sql
  attr_reader :url
  attr_reader :transfer_math
  
  include ChurnPresenter_Helpers
  
  def initialize(request, transfer_math)
    @sql = request.sql
    @url = request.url
    @transfer_math = transfer_math
    @request = request
  end
  
end