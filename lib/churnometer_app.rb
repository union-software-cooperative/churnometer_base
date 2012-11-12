#  Churnometer - A dashboard for exploring a membership organisations turn-over/churn
#  Copyright (C) 2012-2013 Lucas Rohde (freeChange) 
#  lukerohde@gmail.com
#
#  Churnometer is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Churnometer is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with Churnometer.  If not, see <http://www.gnu.org/licenses/>.

require './lib/dimension'

class ChurnometerApp
  # A Dimensions instance containing both custom and inbuilt dimensions.
  attr_reader :dimensions

  # Dimensions that are defined by users in the config file.
  attr_reader :custom_dimensions

  # Dimensions that are hardcoded in the app and are necessary for the program's functioning, such as
  # 'status'.
  attr_reader :builtin_dimensions

  # An AppRoles instance containing all of the possible authorisation roles that a user can assume.
  attr_reader :roles
  
  # Optional name overrides for table columns
  attr_reader :col_names
  
  # Optional descriptions of columns used in tool tips
  attr_reader :col_descriptions

  # Descriptions of all possible summary tables (only used to get data entry dimension)
  attr_reader :summary_user_data_tables
  
  # application_environment: either ':production' or ':development'
  # config_io:  general config filename or stream.  If nil, will load general config 
  #   config from default path
  # site_config_io:  site specific config filename or stream that can't be versioned 
  #   because it contains passwords.  If nil, will load general config from default path
  # The ChurnometerApp instance assumes ownership of the IO instance and closes it when no longer 
  #	needed.
  def initialize(application_environment = :development, site_config_io = nil, config_io = nil)
    @application_environment = application_environment
    
    reload_config(site_config_io, config_io)
  end

  # Uses the given IO instance to reinitialise config data from a yaml definition.
  # Note that if other systems hold references to objects instantiated by the config system, such as
  # AppRoles or Dimensions, then those systems will still be referring to the outdated data.
  # site_config: a stream or filename to the site specific config 
  # config: a stream or filename to the general config
  def reload_config(site_config = nil, config = nil)
    clear_cached_config_data()

    make_config_file_set(site_config, config)
    make_user_data_tables()
    make_roles()
    make_builtin_dimensions()
    make_custom_dimensions()
    make_drilldown_order()
    make_col_names()
    make_col_desc()
  end
  
  def validate
    application_start_date()
  end
  
  # A ConfigFileSet instance.
  def config
    @config_file_set
  end

  def development?
    @application_environment == :development
  end

  def email_on_error?
    if config()['email_on_error'].nil?
      development? == false
    else
      config()['email_on_error'] != false
    end
  end

  def growth_target_percentage
    if config()['growth_target_percentage'].nil?
      10
    else
      config()['growth_target_percentage'].to_i
    end
  end

  # The first iteration of Churnometer retrieved its results by calling SQL functions.
  # Set 'use_new_query_generation_method: true' in config.yaml to use the new method that produces the 
  # same output, but builds the query string in the Ruby domain rather than SQL.
  def use_new_query_generation_method?
    config()['use_new_query_generation_method'] == true
  end
  
  # This is the date we started tracking data.  
  # The user can't select before this date
  def application_start_date
    result = config().element('application_start_date')
    result.ensure_kindof(Date)
    result.value
  end

  
  # ensure col_names is initialised before access
  def col_names
    @col_names ||= make_col_names
  end

  # Returns a string containing the name of the Query class used to handle Chunometer's 'summary'
  # queries.
  def summary_query_class
    config()['summary_query_class'] || 'QuerySummary'
  end

  def use_database_cache?
    config()['use_database_cache'] != false
  end

  # All available data dimensions.
  def dimensions
    custom_dimensions() + builtin_dimensions()
  end

  def groupby_default_dimension
    dimensions().dimension_for_id_mandatory(config().get_mandatory('default_groupby_dimension_id').value)
  end

  # The dimensions that should be displayed to the user in the filter form's 'groupby' dropdown.
  # app_role: The AppRole of the authenticated user.
  def groupby_display_dimensions(app_role)
    final_dimensions = custom_dimensions().select do |dimension|
      dimension.roles_can_access?([app_role])
    end

    Dimensions.new(final_dimensions)
  end

  # Returns the dimension that should be the drilldown target of the given dimension. 
  # Returns the supplied dimension if no drilldown target is defined for it.
  def next_drilldown_dimension(dimension)
    @drilldown_order[dimension] || dimension
  end

  def member_paying_status_code
    config().get_mandatory('member_paying_status_code').value
  end

  def member_awaiting_first_payment_status_code
    config().get_mandatory('member_awaiting_first_payment_status_code').value
  end

  def member_stopped_paying_status_code
    config().get_mandatory('member_stopped_paying_status_code').value
  end

  # The dimension that expresses work site or company information.
  def work_site_dimension
    dimensions().dimension_for_id_mandatory(config().get_mandatory('work_site_dimension_id').value)
  end

  # The AppRole instance that describes a user in an authenticated state. This role is assumed when
  # authorisation fails.
  def unauthenticated_role
    @unauthenticated_role ||= AppRoleUnauthenticated.new
  end

protected
  # This method should clear any data that was generated from config data and stored in instance
  # variables.
  def clear_cached_config_data
    @dimensions = nil
  end
  
  def config_filename
    @config_filename ||= "./config/config.yaml"
  end

  def config_io
    @config_io ||= File.new(config_filename())
  end
  
  def site_config_filename
    @site_config_filename ||= "./config/config_site.yaml"
  end

  def site_config_io
    @site_config_io ||= File.new(site_config_filename())
  end

  # site_config: stream of filename to site specific config, with passwords etc...
  # config: stream or filename
  def make_config_file_set(site_config, config)
    @config_file_set = ConfigFileSet.new
    
    if !config.nil?
      if @config.is_a?(String)
        @config_filename = config # io stream will load from this file
      else
        @config_io = config
        @config_filename = config.class() # so there isn't any confusion
      end
    end
    
    begin 
      @config_file_set.add(ConfigFile.new(config_io()))
    rescue
      puts "Site config file '#{config_filename()}' missing, proceeding without general config."
    end

    if !site_config.nil?
      if @site_config.is_a?(String)
        @site_config_filename = site_config # io stream will load from this file
      else
        @site_config_io = site_config
        @site_config_filename = site_config.class() # so there isn't any confusion
      end
    end
    
    begin
      @config_file_set.add(ConfigFile.new(site_config_io()))
    rescue ConfigFileMissingException
      puts "Site config file '#{site_config_filename()}' missing, proceeding without site-specific config."
    end
  end

  def make_builtin_dimensions
    @builtin_dimensions =
      begin
        dimensions = Dimensions.new
        dimensions.add(Dimension.new('status'))
        dimensions
      end
  end

  def make_custom_dimensions
    raise "Builtin dimensions must have been created first." if @builtin_dimensions.nil?

    dimensions = Dimensions.new

    dimensions.from_config_element(config().get_mandatory('dimensions'), @builtin_dimensions, @roles)

    @custom_dimensions = dimensions
  end

  def make_drilldown_order
    @drilldown_order = {}

    element = config().element('drilldown_order')
    return if element.nil?

    element.ensure_kindof(Hash)

    element.value.each do |key_id, value_element|
      begin
        src_dim = dimensions().dimension_for_id_mandatory(key_id)
        dst_dim = dimensions().dimension_for_id_mandatory(value_element.value)
        @drilldown_order[src_dim] = dst_dim
      rescue Dimensions::MissingDimensionException => e
        raise BadConfigDataFormatException.new(element, e.to_s)
      end
    end
  end


  def make_roles
    @roles = AppRoles.new
    @roles.from_config_element(config().get_mandatory('roles'),
                               @summary_user_data_tables,
                               @detail_user_data_tables)
  end

  def make_user_data_tables
    @summary_user_data_tables = UserDataTables.new.from_config_element(config().get_mandatory('summary_data_tables'))
    @detail_user_data_tables = UserDataTables.new.from_config_element(config().get_mandatory('detail_data_tables'))
  end
  
   # This is the names used for column headings
  def make_col_names
    @col_names = {}
    element = config().element('column_names')
    return if element.nil?

    element.ensure_kindof(Hash)

    element.value.each do |key_id, value_element|
      begin
        @col_names[key_id] = value_element.value
      rescue Dimensions::MissingDimensionException => e
        raise BadConfigDataFormatException.new(element, e.to_s)
      end
    end
    @col_names
  end
  
  # This is the tool tips for each column
  def make_col_desc
    @col_descriptions = {}
    
    element = config().element('column_descriptions')
    return if element.nil?

    element.ensure_kindof(Hash)

    element.value.each do |key_id, value_element|
      begin
        v = String.new(value_element.value)
        
        # replace all {column_id} in the column description with column names
        col_names.each do |cnk, cnv|
          v.gsub! "{#{cnk}}", cnv
        end  
        
        @col_descriptions[key_id] = v
      rescue Dimensions::MissingDimensionException => e
        raise BadConfigDataFormatException.new(element, e.to_s)
      end
    end
    @col_descriptions
  end
  
  

protected
  # User data tables should be accessed via an AppRole instance when performing application logic for 
  # the user.
  #attr_accessor :summary_user_data_tables
  attr_accessor :detail_user_data_tables
end


