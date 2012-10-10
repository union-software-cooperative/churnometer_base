require './lib/dimension'

class ChurnometerApp
  # A Dimensions instance containing both custom and inbuilt dimensions.
  attr_reader :dimensions

  # Dimensions that are defined by users in the config file.
  attr_reader :custom_dimensions

  # Dimensions that are hardcoded in the app and are necessary for the program's functioning, such as
  # 'status'.
  attr_reader :builtin_dimensions

  class ConfigDataException < RuntimeError
    def initialize(message, churnometer_app)
      full_message = "#{message} in config file(s) #{churnometer_app.config_filenames.join(', ')}"
      super(full_message)
    end
  end

  class BadConfigDataFormatException < ConfigDataException
  end

  class MissingConfigDataException < ConfigDataException
  end

  def initialize
    # dbeswick: temporary, to ease migration to ChurnobylApp class.

    # prevent warning about redefining the constant 'Config'.
    # The ruby interpreter defines 'Config', but its use is deprecated.
    Object.module_eval { remove_const(:Config) }
    Object.const_set(:Config, config_hash().values.inject({}, :merge) )

    make_builtin_dimensions()
    make_custom_dimensions()
    make_drilldown_order()
  end

  # The first iteration of Churnometer retrieved its results by calling SQL functions.
  # Set 'use_new_query_generation_method: true' in config.yaml to use the new method that produces the 
  # same output, but builds the query string in the Ruby domain rather than SQL.
  def use_new_query_generation_method?
    config_value('use_new_query_generation_method') == true
  end

  def summary_query_class
    config_value('summary_query_class') || 'QuerySummary'
  end

  def use_database_cache?
    config_value('use_database_cache') != false
  end

  # All available data dimensions.
  def dimensions
    @dimensions ||= custom_dimensions() + builtin_dimensions()
  end

  def groupby_default_dimension
    dimensions().dimension_for_id_mandatory(config_value('default_groupby_dimension_id'))
  end

  # The dimensions that should be displayed to the user in the filter form's 'groupby' dropdown.
  def groupby_display_dimensions(is_leader, is_admin)
    roles = []

    if is_leader
      roles << 'leader'
    end
    
    if is_admin
      roles << 'admin'
    end

    final_dimensions = custom_dimensions().select do |dimension|
      dimension.roles_can_access?(roles)
    end

    Dimensions.new(final_dimensions)
  end

  # Returns the dimension that should be the drilldown target of the given dimension. 
  # Returns the supplied dimension if no drilldown target is defined for it.
  def next_drilldown_dimension(dimension)
    @drilldown_order[dimension] || dimension
  end

  def member_paying_status_code
    config_value('member_paying_status_code')
  end

  def member_awaiting_first_payment_status_code
    config_value('member_awaiting_first_payment_status_code')
  end

  def member_stopped_paying_status_code
    config_value('member_stopped_paying_status_code')
  end

  # The dimension that expresses work site or company information.
  def work_site_dimension
    dimensions().dimension_for_id_mandatory(config_value('work_site_dimension_id'))
  end

  def config_filenames
    config_hash().keys
  end

  # This method is public mostly for the use of legacy code that uses the old settings method.
  #
  # When creating new config data, please create an accessor for that data that calls config_value and
  # returns appropriate data, rather than asking users of the data to call config_value themselves.
  #
  # i.e.: 
  #
  # churnometer_app.work_site_dimension
  #
  # instead of
  #
  # churnometer_app.dimensions[churnometer_app.config_value('work_site_dimension')]
  def config_value(config_key)
    config_hash().each_value do |hash|
      value = hash[config_key]
      return value if value
    end

    return nil
  end

  def config_has_value?(config_key)
    @config_hash.values.find{ |hash| hash.has_key?(config_key) } != nil
  end

protected
  def config_filename
    "./config/config.yaml"
  end

  def site_config_filename
    "./config/config_site.yaml"
  end

  def config_hash
    @config_hash ||= 
      begin
        config = {}

        if !File.exist?(config_filename())
          raise MissingConfigDataException.new("File not found", self)
        end

        yaml = File.read(config_filename())

        # Convert tabs to spaces so there's one less thing for users to get wrong.
        yaml.gsub!("\t", '    ')

        config[config_filename()] = YAML.load(yaml)

        if File.exist?(site_config_filename())
          yaml = File.read(site_config_filename())

          yaml.gsub!("\t", '    ')

          config[site_config_filename()] = YAML.load(yaml)
        end

        config
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

    if !config_has_value?('dimensions')
      raise MissingConfigDataException.new("No 'dimensions' category was found", self)
    end

    dimensions.from_config_hash(config_value('dimensions'), @builtin_dimensions)

    @custom_dimensions = dimensions
  end

  def make_drilldown_order
    @drilldown_order = {}

    hash = config_value('drilldown_order')
    return if hash.nil?

    raise BadConfigDataFormatException.new("'drilldown_order' must be a hash (type is '#{hash.class}')", self) if !hash.kind_of?(Hash)

    hash.each do |k, v|
      begin
        src_dim = dimensions()[k]
        dst_dim = dimensions()[v]
        @drilldown_order[src_dim] = dst_dim
      rescue MissingDimensionException => e
        raise BadConfigDataFormatException.new("drilldown_order: #{e}", self)
      end
    end
  end
end


