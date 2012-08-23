require './lib/settings.rb'

class ChurnPresenter_Form
  
  include ChurnPresenter_Helpers
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
      
      f1 = @request.parsed_params[Filter].reject{ |column_name, id | id.empty? }
      f1 = f1.reject{ |column_name, id | column_name == 'status' }
      
      if !f1.nil?
        f1.each do |column_name, ids|
          Array(ids).each do |id|
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
    end
    
    @filters
  end
  
  def row_header_id_list
    @request.data.group_by{ |row| row['row_header1_id'] }.collect{ | rh | rh[0] }.join(",")
  end

  def output_group_selector(selected_group_id, control_name, control_id='')
    output = "<select name='#{control_name}' id='#{control_id}'>"

    group_names().each do |column_name, name|
      attributes = 
        if column_name == selected_group_id
          "selected='selected'"
        else
          ""
        end
      
      output << "<option value='#{h column_name}' #{attributes}>#{h name}</option>"
    end

    output << "</select>"
    output
  end

  def output_filter_group_search_term_editor
    <<-EOS
			<input type=text id=search_term_add_text />
			<input type=hidden id=search_term_add_id_hidden />
		EOS
  end

  def output_filter_terms_adder
    output = ''
    output << output_group_selector(nil, '', "search_term_add_group")
    output << output_filter_group_search_term_editor()
    output
  end
  
  private

  def filter_value(value)
    value.sub('!','').sub('-','')
  end
  
end
