# An Enumerable collection of data dimensions, in the form of Dimension instances.
# Access the main collection of dimensions via the ChurnometerApp instance.
class Dimensions
  include Enumerable

  class MissingDimensionException < Exception
  end

  # dimensions: Optional Dimension instances with which to initialize the Dimensions object.
  def initialize(dimensions = [])
    @id_to_dimension = {}

    dimensions.each{ |dimension| add(dimension) }
  end

  def initialize_copy(rhs)
    @id_to_dimension = rhs.instance_variable_get(:@id_to_dimension).dup
  end

  # config_hash: mappings from index numbers to hashes defining Dimension columns in the format defined by the Churnometer configuration scheme.
  # inbuilt_dimensions: Dimensions defined by the app outside of the config file.
  def from_config_hash(config_hash, inbuilt_dimensions)
    config_hash.each do |index, config_hash_entry|
      dimension = DimensionUser.new(index)
      dimension.from_config_hash(config_hash_entry)
      add(dimension)
    end

    all_dimensions = self + inbuilt_dimensions

    each() do |user_dimension|
      user_dimension._post_load_from_config_hash(all_dimensions)
    end
  end

  # Returns a new Dimensions instance containing all the Dimension instances in the two terms.
  def + (dimensions)
    result = dup()

    dimensions.each do |dimension|
      result.add(dimension)
    end

    result
  end

  # dimension: an instance of a Dimension object.
  def add(dimension)
    if @id_to_dimension.has_key?(dimension.id)
      raise "Dimension with id #{dimension.id} has already been added."
    end

    @id_to_dimension[dimension.id] = dimension
  end

  # Returns 'nil' if no dimension by that id exists.
  def dimension_for_id(id)
    @id_to_dimension[id]
  end

  alias_method :[], :dimension_for_id

  # Accepts a dimension id optionally in the form of 'old<id>', 'new<id>' or 'current<id>'.
  # Returns a DimensionDelta instance if a delta prefix is given in the id.
  # Otherwise a regular Dimension instance is returned.
  # Returns nil if no Dimension of the given base id is found.
  #
  # tbd: these ids originate from configuration data. 
  # Maybe find a more explicit way to refer to dimension deltas instead of using this naming 
  # convention.
  def dimension_for_id_with_delta(id)
    m = /(old|new|current)?(.+)/.match(id)

    delta_part = m[1]
    id_part = m[2]

    base_dimension = dimension_for_id(id_part)

    if base_dimension.nil?
      nil
    elsif delta_part.nil?
      base_dimension
    else
      case delta_part
        when 'old' then base_dimension.delta_old
        when 'current' then base_dimension.delta_current
        when 'new' then base_dimension.delta_new
      end
    end
  end

  # As for dimension_for_id, but raises an exception if the dimension isn't present.
  def dimension_for_id_mandatory(id)
    result = dimension_for_id(id)

    if result.nil?
      raise MissingDimensionException, "Dimension with id '#{id}' is missing (dimension is undefined.)"
    end

    result
  end

  # Iterates through each Dimension instance held by the object.
  def each(&block)
    @id_to_dimension.values.each(&block)  
  end
end

# Base class for metadata about database dimensions.
# A dimension is a set of data that can be used in query filters and to group query results.
class DimensionBase
  # The 'base name' of the column that stores data for the dimension in the memberfact tables.
  def column_base_name
    raise 'abstract'
  end

  # The human-readable name of the dimension.
  def name
    raise 'abstract'
  end

  # Describes the dimension instance for debugging purposes.
  def describe
    "#{self.class.name}: column: #{column_base_name()}"
  end

  def to_s
    "#<#{describe()}>"
  end
end

# Metadata about in-built dimensions, and base class for user dimension definitions.
# Can be used to retrieve the database column that encodes the dimension, and also those columns that
# encode delta information about the dimension.
class Dimension < DimensionBase
  attr_reader :id

  # The 'delta' readers return DimensionDelta instances. These are used to refer to deltas that
  # are returned from queries, i.e. changes in status or company. 
  # The instances returned can be queried to retreive the database column names for the delta results, 
  # i.e. oldcol0, newcol0, etc.
  attr_reader :delta_old
  attr_reader :delta_current
  attr_reader :delta_new

  # index: the index number of the generic column for the dimension.
  def initialize(id)
    @id = id
    @delta_old = DimensionDelta.new(self, 'old')
    @delta_current = DimensionDelta.new(self, 'current')
    @delta_new = DimensionDelta.new(self, 'new')
  end

  def column_base_name
    id()
  end

  def name
    id()
  end

  def describe
    "#{super} id: #{id()}"
  end
end

# Defines a dimension representing delta changes in a given dimension's data.
# An example is oldstatus, newstatus as delta dimension for the status dimension.
class DimensionDelta < DimensionBase
  # dimension: The master Dimension instance indicating the database dimension that this instance is a
  #		delta of.
  # delta_prefix: The string prepended to the database column name that forms the final column name
  #		that can be used to refer to database query result columns.
  def initialize(dimension, delta_prefix)
    @dimension = dimension
    @delta_prefix = delta_prefix
  end

  def column_base_name
    "#{@delta_prefix}#{@dimension.column_base_name}"
  end

  def name
    "#{@delta_prefix.capitalize} #{@dimension.name}"
  end

  def id
    "#{@delta_prefix}#{@dimension.id}"
  end

  def describe
    "#{super} for parent column: #{@dimension.describe}"
  end
end

# A customisable dimension that is set up by users in the config file.
class DimensionUser < Dimension
  attr_reader :name
  attr_reader :allowed_roles
  attr_reader :drilldown_target_dimension

  # The index of the dimension as given in the user config file.
  attr_reader :index

  # index: the index number of the generic column for the dimension.
  def initialize(index)
    super(nil)
    @index = index
  end

  # config_hash: mappings from index numbers to hashes defining Dimension columns. 
  # The hash format is defined by the Churnometer configuration file scheme.
  def from_config_hash(config_hash)
    @id = config_hash['id'].downcase
    @name = config_hash['name']
    @allowed_roles = config_hash['roles'] || ['any']
    @drilldown_target_dimension = config_hash['drilldown_target']
  end

  # Intended for the use of the Dimensions class only, to be called after load_from_config_hash.
  # all_dimensions: the Dimensions instance containing all the inbuilt and user Dimension instances.
  def _post_load_from_config_hash(all_dimensions)
    if !@drilldown_target_dimension.nil?
      @drilldown_target_dimension = all_dimensions.dimension_for_id_mandatory(@drilldown_target_dimension)
    end
  end

  def column_base_name
    "col#{@index}"
  end

  def roles_can_access?(role_names)
    @allowed_roles.include?('any') ||
      (!@allowed_roles.include?('none') && role_names.any?{ |s| @allowed_roles.include?(s) })
  end
end
