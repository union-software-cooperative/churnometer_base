require './lib/helpers.rb'
require './lib/constants.rb'
require 'spreadsheet'

class ChurnPresenter
  attr_reader :data
  attr_reader :params
  attr_reader :auth
  
  attr_accessor :transfers
  attr_accessor :target
  attr_accessor :form
  attr_accessor :tables
  attr_accessor :graph
  
  include Enumerable
  include Helpers
  include Mappings # for to_excel - todo refactor
  
  def initialize(data, params, auth)
    @data = data
    @params = params
    @auth = auth
    
    @transfers = ChurnPresenter_Transfers.new data, params
    @form = ChurnPresenter_Form.new data, params
    @target = ChurnPresenter_Target.new data, params if (auth.leader? || auth.lead?) && params['column'].to_s == ''
    @graph = ChurnPresenter_Graph.new data, params
    @graph = nil unless (@graph.line? || @graph.waterfall?)
    
  end

  # Properties
  
  def has_data?
    data && data.count > 0
  end
  
  # Wrappers
  
  def each(&block)
    data.each &block
  end

  def count
    data.count
  end
  
  def [](index)
    data[index]
  end
  
  def tabs
    hash = Hash.new
    
    if !@graph.nil? 
      hash['graph'] = 'Graph'
    end
    
    if !@tables.nil?
        @tables.each do | key, value |
          hash[key] = value
        end
    end
    
    if !@transfers.nil?
        hash['transfers'] = 'Transfers'
    end
    
    hash['diags'] = 'Diagnostics'
    
    hash
  end
  
  def to_excel
    book = Spreadsheet::Excel::Workbook.new
    sheet = book.create_worksheet

    if Filter!='f' 
      throw
    end
    
    if has_data?
    
      #Get column list
      if params['table'].nil?
        cols = [0]
      elsif summary_tables.include?(params['table'])
          cols = summary_tables[params['table']]
      else
        cols = ['memberid'] | member_tables[params['table']]  
      end
    
      # Add header
      merge_cols(data[0], cols).each_with_index do |hash, x|
        sheet[0, x] = col_names[hash.first] || hash.first
      end
  
      # Add data
      data.each_with_index do |row, y|
        merge_cols(row, cols).each_with_index do |hash,x|
        
          if filter_columns.include?(hash.first) 
            sheet[y + 1, x] = hash.last.to_i
          else
              sheet[y + 1, x] = hash.last
          end  
        end
      end
    end
  
    path = "tmp/data.xls"
    book.write path
  
    path
  end
  
end

module ChurnPresenter_Helpers
  
  include Rack::Utils
  alias_method :h, :escape_html # needed for build_uri - refactor
  
  def paying_start_total(data)
    # can't figure out enumerable way to sum this
    # group by is when running totals are shown because you don't want to sum a running start count.
    # so only count the first row for each group (v[0])
    t=0
    data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[0]['paying_start_count'].to_i
    end
    t
  end

  def paying_end_total(data)
    # can't figure out enumerable way to sum this
    # group by is when running totals are shown because you don't want to sum a running end count.
    # so only count the last row for each group (v.count-1)
    t=0
    data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[v.count-1]['paying_end_count'].to_i
    end
    t
  end
  
  def paying_transfers_total(data)
    t=0
    data.group_by{ |row| row['row_header1'] }.each do | row, v |
      t += v[0]['paying_other_gain'].to_i + v[0]['paying_other_loss'].to_i
    end
    t
  end

  def drill_down_header_link(group, value, next_group)
    # TODO I think this should be somewhere that abstracts filter logic
    build_uri ({"#{Filter}[#{group}]" => value, "group_by" => next_group })
  end
  
  def build_uri(query_hashes)
    #TODO refactor out params if possible, or put this somewhere better
    
    # build uri from params
    query = params.reject{ |k,v| v.empty? }.reject{ |k, v| k == Filter}
    
    # flatten filters
    params[Filter].reject{ |k,v| k == 'status'}.each do |k, v|
      query["#{Filter}[#{k}]"] = v
    end
    
    # merge new items
    query.merge! query_hashes
    
    # make uri string
    uri = '/?'
    query.each do |key, value|
      uri += "&#{h key}=#{h value}" 
    end
    
    uri.sub('/?&', '/?')
  end
  
end

class ChurnPresenter_Transfers
  attr_reader :data
  attr_reader :params
  
  include Helpers
  include Mappings
  include ChurnPresenter_Helpers
  
  def initialize(data, params)
    @data = data
    @params = params
  end
  
  def exists?
    # count the transfers, including both in and out
    start_date = Date.parse(params['startDate'])
    end_date = Date.parse(params['endDate'])
    months = Float(end_date - start_date) / 30.34
    
    t=0
    data.each do |row|
      t += row['external_gain'].to_i - row['external_loss'].to_i
    end

    startcnt =  paying_start_total(data)
    endcnt = paying_end_total(data)
    
    threshold = ((startcnt + endcnt)/2 * (MonthlyTransferWarningThreshold * months))
    t > threshold ? true : false
  end
  
end

class ChurnPresenter_Form
  
  attr_reader :data
  attr_reader :params
  
  include Mappings
  
  def initialize(data, params)
    @params = params
    @data = data
  end
  
  def [](index)
    params[index]
  end
  
  def filters
    if @filters.nil?
      @filters = Array.new
      
      f1 = (params[Filter]).reject{ |column_name, id | id.empty? }
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
    data.group_by{ |row| row['row_header1_id'] }.collect{ | rh | rh[0] }.join(",")
  end
  
  private
  
  def db
    @db ||= ChurnData.new
  end
  
  def filter_value(value)
    value.sub('!','').sub('-','')
  end
  
  
end

class ChurnPresenter_Target
  
  attr_reader :data
  attr_reader :params
  
  include ChurnPresenter_Helpers
  include Mappings
  
  def initialize(data, params)
    @data = data
    @params = params
  end
  
  def weeks
    start_date = Date.parse(params['startDate'])
    end_date = Date.parse(params['startDate'])
    
    (Float(end_date - start_date) / 7).round(1)
  end
  
  def growth
    start_date = Date.parse(params['startDate'])
    end_date = Date.parse(params['endDate'])
  
    start_count = paying_start_total(data)
    
    started = 0
    data.each { | row | started += row['paying_real_gain'].to_i }
    
    stopped = 0
    data.each { | row | stopped += row['paying_real_loss'].to_i }
    
    end_count = start_count + stopped + started
    
    start_date == end_date || start_count == 0 ? Float(1/0.0) : Float((((Float(end_count) / Float(start_count)) **  (365.0/(Float(end_date - start_date)))) - 1) * 100).round(1)
  end

  def get_cards_in_growth_target
    
    # the number of people who stopped paying
    stopped = 0
    data.each { | row | stopped -= row['paying_real_loss'].to_i }
    
    # count the people who start paying without giving us a card
    # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
    resume = 0 
    data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 
    
    # count of a1p people who start paying
    conversions = 0
    data.each { | row | conversions -= row['a1p_to_paying'].to_i }
    
    # count the joiners who fail to convert to paying
    failed = 0 
    data.each { | row | failed -= row['a1p_to_other'].to_i }
    
    # count the joiners who fail to convert to paying
    cards = 0 
    data.each { | row | cards += row['a1p_real_gain'].to_i }
    
    start_date = Date.parse(params['startDate'])
    end_date = Date.parse(params['endDate'])
    
    cards_per_week = 0.0
    if start_date != end_date  
      growth = Float((paying_start_total(data) + paying_transfers_total(data))) * 0.1 / 365 * Float(end_date - start_date) # very crude growth calculation - But I don't think CAGR makes sense, the formula would be # growth = (((10% + 1) ^ (duration/365) * start) - start) 
       
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
    data.each { | row | stopped -= row['paying_real_loss'].to_i }
    
    # count the people who start paying without giving us a card
    # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
    resume = 0 
    data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 
    
    # count the joiners who fail to convert to paying
    failed = 0 
    data.each { | row | failed -= row['a1p_to_other'].to_i }
    
    start_date = Date.parse(params['startDate'])
    end_date = Date.parse(params['endDate'])
    
    cards_per_week = 0.0
    if start_date != end_date  
      cards_per_week = Float((Float(stopped - resume + failed) / Float(end_date - start_date) * 7 )).round(1)
    end
    
    cards_per_week
  end

  def getmath_get_cards_in_target

     # the number of people who stopped paying
     stopped = 0
     data.each { | row | stopped -= row['paying_real_loss'].to_i }

     # count the people who start paying without giving us a card
     # we calculate this by subtracting the people who become paying from a1p (a1p_to_paying which is negative) from the paying gain
     resume = 0 
     data.each { | row | resume += (row['paying_real_gain'].to_i + row['a1p_to_paying'].to_i) } 

     paying_real_gain = 0 
     data.each { | row | paying_real_gain += row['paying_real_gain'].to_i } 
     
     a1p_to_paying = 0 
     data.each { | row | a1p_to_paying += row['a1p_to_paying'].to_i } 
     
     # count the joiners who fail to convert to paying
     failed = 0 
     data.each { | row | failed -= row['a1p_to_other'].to_i }

     start_date = Date.parse(params['startDate'])
     end_date = Date.parse(params['endDate'])

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
    data.each { | row | cards += row['a1p_real_gain'].to_i }
    
    start_date = Date.parse(params['startDate'])
    end_date = Date.parse(params['endDate'])
    
    cards_per_week = 0.0
    if start_date != end_date  
      cards_per_week = Float(((cards) / Float(end_date - start_date) * 7 )).round(1)
    end
    
    cards_per_week
  end
   
  def periods
    data.group_by{ |row| row['period_header'] }.sort{|a,b| a[0] <=> b[0] }
  end
  
  def pivot(next_group_by)
    series = Hash.new
    
    rows = data.group_by{ |row| row['row_header1'] }
    rows.each do | row |
      series[row[0]] = Array.new
      periods(data).each do | period |
        intersection = row[1].find { | r | r['period_header'] == period[0] }
        if intersection.nil? 
          series[row[0]] << "{ y: null }"
        else
          series[row[0]] << "{ y: #{intersection['running_paying_net'] }, id:'&intervalStart=#{intersection['period_start']}&intervalEnd=#{intersection['period_end']}&interval=none&f[#{(params['group_by'] || 'branchid')}]=#{intersection['row_header1_id']}&#{next_group_by}' }"
        end
      end
    end
  
    series
  end

  def getmath_transfers?
    # count the transfers, including both in and out
    start_date = Date.parse(params['startDate'])
    end_date = Date.parse(params['endDate'])
    months = Float(end_date - start_date) / 30.34
    
    t=0
    data.each do |row|
      t += row['external_gain'].to_i - row['external_loss'].to_i
    end

    startcnt =  paying_start_total(data)
    endcnt = paying_end_total(data)

    threshold = ((startcnt + endcnt)/2 * (MonthlyTransferWarningThreshold * months))
    t > threshold ? true : false
  
    "The system will warn the user and display this tab, when the external transfer total (#{t}) is greater than the external transfer threshold (#{threshold.round(0)} = (average size (#{(startcnt+endcnt)/2} = (#{col_names['paying_start_count']} (#{startcnt}) + #{col_names['paying_end_count']} (#{endcnt}))/2) * MonthlyThreshold (#{(MonthlyTransferWarningThreshold*100).round(1)}%) x months (#{months.round(1)}))).  The rational behind this formula is that 100% of the membership will transfer to growth from development and back every three years (2.8% in and 2.8% out each month). So transfers below this threshold are typical and can be ignored, as opposed to atypical area restructuring of which the user needs warning."
  end
end

class ChurnPresenter_Graph
  attr_reader :data
  attr_reader :params
  
  include Helpers
  include Mappings
  include ChurnPresenter_Helpers
  
  def initialize(data, params)
    @data = data
    @params = params
  end
    
  def series_count
    rows = data.group_by{ |row| row['row_header1'] }.count
  end

  def line?
    series_count <= 30 && params['group_by'] != 'statusstaffid' && params['column'].empty? && params['interval'] != 'none'
  end

  def waterfall?
    cnt =  data.reject{ |row | row["paying_real_gain"] == '0' && row["paying_real_loss"] == '0' }.count
    cnt > 0  && cnt <= 30 && params['group_by'] != 'statusstaffid' && params['column'].empty? && params['interval'] == 'none'
  end
  
  def items
    a = Array.new
    data.each do |row|
      i = (Struct.new(:name, :gain, :loss, :link)).new
      i[:name] = row['row_header1']
      i[:gain] = row['paying_real_gain']
      i[:loss] = row['paying_real_loss']
      i[:link] = drill_down_header_link(params['group_by'], row['row_header1_id'], next_group_by[params['group_by']]) 
      a << i
    end
    a
  end
  
  def total
    t = 0;
    data.each do |row|
      t += row['paying_real_gain'].to_i + row['paying_real_loss'].to_i
    end
    t
  end
end

class ChurnPresenter_Tables
end