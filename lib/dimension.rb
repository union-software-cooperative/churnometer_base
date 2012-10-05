class Dimensions
  include Enumerable

  class MissingDimensionException < Exception
  end

  def initialize
    @id_to_dimension = {}
  end

  def initialize_copy(rhs)
    @id_to_dimension = rhs.instance_variable_get(:@id_to_dimension).dup
  end

  # config_hash: mappings from index numbers to hashes defining Dimension columns in the format defined by the Churnometer configuration scheme.
  def from_config_hash(config_hash)
    config_hash.each do |index, config_hash_entry|
      dimension = DimensionUser.new(index)
      dimension.from_config_hash(config_hash_entry)
      add(dimension)
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

# Information about a set of data that can be used in query filters and to group query results.
class Dimension
  attr_reader :id

  # index: the index number of the generic column for the dimension.
  def initialize(id)
    @id = id
  end

  # The 'base name' of the column that stores data for the dimension in the memberfact tables.
  def column_base_name
    id()
  end
end

# A customisable dimension that is set up by users in the config file.
class DimensionUser < Dimension
  attr_reader :name

  # The index of the dimension as given in the user config file.
  attr_reader :index

  # index: the index number of the generic column for the dimension.
  def initialize(index)
    super(nil)
    @index = index
  end

  # config_hash: mappings from index numbers to hashes defining Dimension columns in the format defined by the Churnometer configuration scheme.
  def from_config_hash(config_hash)
    @id = config_hash['id'].downcase
    @name = config_hash['name']
  end

  # The 'base name' of the column that stores data for the dimension in the memberfact tables.
  def column_base_name
    "col#{@index}"
  end
end
