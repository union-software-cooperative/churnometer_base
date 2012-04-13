require './lib/helpers.rb'
require './lib/constants.rb'
require 'spreadsheet'

class ChurnPresenter
  attr_reader :data
  attr_reader :params
  attr_reader :leader
  attr_reader :staff
  
  include Enumerable
  include Helpers
  
  def initialize(data, params, leader, staff)
    @data = data
    @params = params
    @leader = leader
    @staff = staff
  end

  # Properties
  
  def has_data?
    data && data.count > 0
  end
  
  def interval_selections
    [
      ["none", "Off"],
      ["week", "Weekly"],
      ["month", "Monthly"],
    ]
  end
  
  def leader?
    leader
  end
  
  def staff?
    staff
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