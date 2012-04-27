require './lib/settings.rb'

class ChurnPresenter_Tables
  attr_accessor :tables
  
  include Enumerable
  include Settings
  
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
    @tables.find{ |t| t.id == index.downcase }
  end
end



class ChurnPresenter_Table
  attr_reader :id
  attr_reader :name
  attr_reader :type
  attr_reader :columns
  
  include Settings
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
  
  def date_col(column_name)
    date_cols.include?(column_name) ? "class=\"{sorter: 'medDate'}\"" : ""
  end
  
  def display_cell(column_name, row)
	  value = row[column_name]
	  
	  if date_cols.include?(column_name)
	    value = format_date(row[column_name])
	  end 
	  
	  #todo figure out why this doesn't work for member tables
	  if column_name == 'changedate'
	    value = Date.parse(row['changedate']).strftime(DateFormatDisplay)
	  end
    
    if column_name == 'row_header1'
      content = "<a href=\"#{build_url(drill_down_header(row)) }\">#{row['row_header1']}</a>"
    elsif column_name == 'period_header'
      content = "<a href=\"#{build_url(drill_down_interval(row))}\">#{value}</a>"
    elsif can_detail_cell? column_name, value
      content = "<a href=\"#{build_url(drill_down_cell(row, column_name)) }\">#{value}</a>"
    elsif can_export_cell? column_name, value
      content = "<a href=\"export_table#{build_url(drill_down_cell(row, column_name).merge!({'table' => 'membersummary'}))}\">#{value}</a>"
    else 
      content = value
    end
		
		if bold_col?(column_name)
        bold(content)
    else
      content
    end
  end
  
  def display_footer(column_name, total)

    if !no_total.include?(column_name)
      if can_detail_cell?(column_name, total)
        content = "<a href=\"#{build_url(drill_down_footer(column_name))}\">#{total}</a>"
      elsif can_export_cell?(column_name, total)
          content = "<a href=\"export_table#{build_url(drill_down_footer(column_name).merge!({'table' => 'membersummary'}))}\">#{total}</a>"
      else
        content = total
      end
      
      if bold_col?(column_name)
        bold(content)
      else
        content
      end
    end
  end
  
  def bold(content)
    "<span class=\"bold_col\">#{content}</span>"
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
     @columns.each_with_index do |c, x|
       sheet[0, x] = (col_names[c] || c)
     end

     # Add data
     @data.each_with_index do |row, y|
       @columns.each_with_index do |c,x|
         if filter_columns.include?(c) 
           sheet[y + 1, x] = row[c].to_f
         else
           sheet[y + 1, x] = row[c]
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