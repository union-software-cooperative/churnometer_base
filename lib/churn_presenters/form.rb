require './lib/settings.rb'

class ChurnPresenter_Form
  
  include Settings
  
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
          i[:display] = @request.db.get_display_text(column_name, filter_value(id))
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

  def filter_value(value)
    value.sub('!','').sub('-','')
  end
  
  
end