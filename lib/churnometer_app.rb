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
require './lib/waterfall_chart_config'

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
  
  attr_reader :waiver_statuses

  # application_environment: either ':production' or ':development'
  # config_io:  general config filename or stream.  If nil, will load general config 
  #   config from default path
  # site_config_io:  site specific config filename or stream that can't be versioned 
  #   because it contains passwords.  If nil, will load general config from default path
  # The ChurnometerApp instance assumes ownership of the IO instance and closes it when no longer 
  #	needed.
  def initialize(application_environment = :development, site_config_io = nil, config_io = nil)
    @application_environment = application_environment

    # Special case: force site_config file to the regression config if requested.
    # This necessitates reading the site_config file before the main config processing logic.
    # This isn't appropriate if an explicit site_config_io was given.
    if site_config_io.nil?
      yaml = YAML.load_file(site_config_filename())
      if yaml != false && yaml['use_regression_config'] == true
        @regression_config_override = true
        site_config_io = File.new(regression_config_filename())
      end
    end

    @config_stream_override = 
      !@regression_config_override && site_config_io.nil? == false || config_io.nil? == false

    reload_config(site_config_io, config_io)
  end

  # If the "use_regression_config" option is set, then returns the regression config. Otherwise,
  # returns the regular config filename.
  # If a stream has been used to override the main config, then nil is returned.
  def active_master_config_filename
    if @config_stream_override
      nil
    elsif @regression_config_override
      regression_config_filename()
    else
      config_filename()
    end
  end

  def regression_config_filename
    './spec/config/config_regression.yaml'
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
    make_waiver_statuses()
    validate()
  end
  
  # Config values can be validated at startup in this method. This provides a means of verifying parts
  # of the config without waiting until they're first accessed.
  # Can also be called by systems that modify config data to ensure that changes are valid.
  # Throws an exception if any problem occurs.
  def validate
    application_start_date()
    config().ensure_kindof('waiver_statuses', Array, NilClass)
    validate_email()
    config().ensure_kindof('green_member_statuses', Array, NilClass)

    # Construction will raise an exception if there's an issue.
    WaterfallChartConfig.from_config_element(config().get_mandatory('waterfall_chart_config'))
  end

  # A ConfigFileSet instance.
  def config
    @config_file_set
  end

  def development?
    @application_environment == :development
  end

  def database_import_encoding
    config()['database_import_encoding']
  end

  def email_on_error?
    if config()['email_on_error'].nil?
      development? == false
    else
      config()['email_on_error'] != false
    end
  end

  # The address from which error emails are sent.
  # Returns nil if email_on_error? is false (error emails disabled.)
  def email_on_error_from
    if email_on_error? == false
      nil
    else
      config.element('email_errors').value['from'].value
    end
  end

  # The address to which error emails are sent.
  # Returns nil if email_on_error? is false (error emails disabled.)
  def email_on_error_to
    if email_on_error? == false
      nil
    else
      config.element('email_errors').value['to'].value
    end
  end

  def growth_target_percentage
    if config()['growth_target_percentage'].nil?
      10
    else
      config()['growth_target_percentage'].to_i
    end
  end

  # The name of the database table that contains the member facts.
  def memberfacthelper_table
    database = config().get_mandatory('database')

    if database['facttable'].nil?
      'memberfacthelper'
    else
      database['facttable'].value
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
    result = config().get_mandatory('application_start_date')
    result.ensure_kindof(Date)
    result.value
  end
  
  # ensure col_names is initialised before access
  def col_names
    @col_names ||= make_col_names()
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
    element = config().get_mandatory('member_paying_status_code')
    element.ensure_kindof(String)
    element.value
  end

  def member_awaiting_first_payment_status_code
    element = config().get_mandatory('member_awaiting_first_payment_status_code')
    element.ensure_kindof(String)
    element.value
  end

  def member_stopped_paying_status_code
    element = config().get_mandatory('member_stopped_paying_status_code')
    element.ensure_kindof(String)
    element.value
  end

  # Returns a list of every valid status code that a member can be assigned.
  def all_member_statuses
    result = [member_paying_status_code(), 
              member_awaiting_first_payment_status_code(),
              member_stopped_paying_status_code()]
    result = result | waiver_statuses()
    #result = result | green_member_statuses()
    result
  end

  # Returns the statuses that are used to construct the green bar in the waterfall chart.
  def green_member_statuses
    if config().element('green_member_statuses').value.nil? == false
      config().element('green_member_statuses').value.collect { |e| e.value }
    else
      [member_paying_status_code, member_awaiting_first_payment_status_code]
    end
  end

  # Returns a hash defining the user's desired configuration for the waterfall chart if given, or
  # a default chart configuration.
  def waterfall_chart_config
    WaterfallChartConfig.from_config_element(config().element('waterfall_chart_config'))
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

  def site_config_filename
    @site_config_filename ||= "./config/config_site.yaml"
  end

  # site_config: stream of filename to site specific config, with passwords etc...
  # config: stream or filename
  def make_config_file_set(site_config, config)
    @config_file_set = ConfigFileSet.new
    config_io = nil
    site_config_io = nil

    config ||= config_filename()
    site_config ||= site_config_filename()

    if config.is_a?(String)
      config_io = File.new(config)
      @config_filename = config
    else
      config_io = config
      # Ensure that later error messages report that the config was generated from a non-standard source
      # if necessary.
      @config_filename = 
        if config_io.respond_to?(:path)
          config_io.path
        else
          "unspecified source"
        end
    end

    begin 
      @config_file_set.add(ConfigFile.new(config_io, @config_filename))
    rescue ConfigFileMissingException
      $stderr.puts "Config file '#{config_filename()}' missing, proceeding without general config."
    end

    if site_config.is_a?(String)
      site_config_io = File.new(site_config)
      @site_config_filename = site_config
    else
      site_config_io = site_config
      # Ensure that later error messages report that the config was generated from a non-standard source
      # if necessary.
      @site_config_filename =
        if site_config_io.respond_to?(:path)
          site_config_io.path
        else
          "unspecified source"
        end
    end

    begin
      @config_file_set.add(ConfigFile.new(site_config_io, @site_config_filename))
    rescue ConfigFileMissingException
      $stderr.puts "Site config file '#{site_config_filename()}' missing, proceeding without site-specific config."
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
                               @detail_user_data_tables,
                               config().get_mandatory('database')['password'].value)
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
  
  def make_waiver_statuses()
    element = config().get_mandatory('waiver_statuses')
    element.ensure_kindof(Array, NilClass)

    @waiver_statuses = 
      if element.value.nil?
        []
      else
        element.value.collect do |element|
        	element.ensure_kindof(String)
        	element.value
        end
      end
  end
  
  def validate_email
    if email_on_error?
      config().ensure_kindof('email_errors', Hash)
      config().element('email_errors').value['to'].ensure_kindof(String)
      config().element('email_errors').value['from'].ensure_kindof(String)
    end
  end

  # User data tables should be accessed via an AppRole instance when performing application logic for 
  # the user.
  #attr_accessor :summary_user_data_tables
  attr_accessor :detail_user_data_tables
end


