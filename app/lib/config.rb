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

# Base class of exceptions relating to configuration data.
class ConfigDataException < RuntimeError
end

# Base class of exceptions in the case of a config file not being able to be accessed in some way.
class ConfigFileAccessException < ConfigDataException
  attr_reader :filename

  # filename: The filename of the file at issue.
  def initialize(filename, message)
    @filename = filename
  end
end

# Exception in the case of a config file being present, but not able to be read for some reason.
class ConfigFileUnreadableException < ConfigFileAccessException
  # filename: The filename of the file at issue.
  def initialize(filename)
    full_message = "The config file '#{filename}' couldn't be read."
    super(filename, full_message)
  end
end

# Exception in the case of a config file not being present on disk.
class ConfigFileMissingException < ConfigFileAccessException
  # filename: The filename of the missing file.
  def initialize(filename)
    full_message = "The config file '#{filename}' is missing."
    super(filename, full_message)
  end
end

# Exception raised when certain data is not present in configuration data.
class MissingConfigDataException < ConfigDataException
  # element_id: an id describing the missing data.
  # parent_element: if avaiable, the element that was expected to contain the missing data.
  def initialize(element_id, parent_element = nil)
    full_message = "The config element '#{element_id}' wasn't found in any config file."

    super(full_message)
  end
end

# Base class describing those configuration exceptions that relate to a given config element.
class ConfigDataElementException < ConfigDataException
  attr_reader :config_element

  # config_element: The config element that relates to the problem.
  def initialize(config_element, message)
    @config_element = config_element

    full_message = "#{message} (element '#{config_element.id}' in config file '#{config_element.config_file.filename}')"

    super(full_message)
  end
end

class BadConfigDataFormatException < ConfigDataElementException
end

# Contains the value of a given config key, and information about the source of the ConfigElement
# (i.e. which config file it came from.)
# 'value' may also be another ConfigElement instance. Elements defined as Hashes and Arrays in the
# source config file are turned into hashes and arrays of ConfigElement values.
# In all other cases, 'value' is an instance of the data type given in the config file, i.e. string,
# integer, etc.
class ConfigElement
  attr_reader :config_file
  attr_reader :id
  attr_reader :value

  # id: The id of the element.
  # value: The value of the element as parsed by yaml.
  # config_file: The ConfigFile instance that's the origin of the element.
  def initialize(id, value, config_file)
    @id = id

    # Convert child Hash and Array elements into ConfigElements.
    @value =
      if value.kind_of?(Hash)
        result = {}

        value.each do |hash_key, hash_value|
          result[hash_key] = ConfigElement.new("#{id}/#{hash_key}", hash_value, config_file)
        end

        result
      elsif value.kind_of?(Array)
        result = []

        value.each_with_index do |array_value, index|
          result << ConfigElement.new("#{id} (index #{index})", array_value, config_file)
        end

        result
      else
        value
      end

    @value.freeze # config elements shouldn't be modified
    @config_file = config_file
  end

  # Raises a BadConfigDataFormatException if the ConfigElement's value isn't one of the given class
  # types, as determined by 'kind_of?'
  # Returns this element's value.
  def ensure_kindof(*class_types)
    if !class_types.any?{ |kindof| @value.kind_of?(kindof) }
      raise BadConfigDataFormatException.new(self, "Element is of type '#{@value.class}', but it needs to be of type '#{class_types.join(' or ')}'.")
    end
    @value
  end

  # Raises a MissingConfigDataException if the ConfigElement is a hash that doesn't contain the given
  # hash key.
  # It's an error to call this on ConfigElement instances whose values are of types other than Hash.
  # Returns the key's value.
  def ensure_hashkey(key)
    raise MissingConfigDataException.new(key, self) if !@value.has_key?(key)
    @value[key]
  end

  def has_children?
    @value.kind_of?(Hash) || @value.kind_of?(Array)
  end

  # Returns one of the child ConfigElements of this element.
  # Raises a BadConfigDataFormatException if this element has no children.
  def [](key)
    ensure_kindof(Hash)
    @value[key]
  end

  # If the element has child ConfigElements, then return the value (not the element) of the child for
  # the given key.
  # Return 'nil' if the child isn't present.
  # Raises a BadConfigDataFormatException if this element has no children.
  def optional(key)
    ensure_kindof(Hash)
    element = @value[key]
    if element
      element.value
    else
      nil
    end
  end
end

# Contains mappings from element ids to ConfigElement instances.
class ConfigFile
  include Enumerable

  attr_reader :filename

  # file: A stream or the filename of the config file
  # file_description: If a filename was not given for 'file', then this parameter must describe
  #    the source of the config data.
  def initialize(file, file_description=nil)
    @io = if file.is_a?(String)
      @filename = file

      if !File.exists?(@filename)
        raise ConfigFileMissingException.new(@filename)
      end

      if !File.readable?(@filename)
        raise ConfigFileUnreadableException.new(@filename)
      end

      File.new(@filename)
    else
      raise "file_description must be provided if not supplying a filename." if file_description.nil?
      @filename = file_description
      file
    end

    yaml = @io.read

    @io.close

    # Convert tabs to spaces so there's one less thing for users to get wrong.
    yaml.gsub!("\t", '    ')

    config_hash = YAML.load(yaml)

    # This will be true in the case of an empty file.
    if config_hash == false
      config_hash = {}
    end

    raise BadConfigDataFormatException.new("The config file definition must result in a hash, but the type is '#{config_hash.class}'", self) if !config_hash.kind_of?(Hash)

    @values = {}

    config_hash.each do |element_id, value|
      @values[element_id] = ConfigElement.new(element_id, value, self)
    end
  end

  def [](element_id)
    @values[element_id]
  end

  def each(&block)
    @values.each(&block)
  end

  def has_element?(element_id)
    @values.has_key?(element_id)
  end

  def to_s
    @filename
  end
end

# Compiles a single set of queryable config data from multiple config files.
# Values defined in later-added ConfigFile instances take precedence over earlier-added instances.
class ConfigFileSet
  def initialize
    @config_files = []
  end

  def add(config_file)
    @config_files.insert(0, config_file)
  end

  def filenames
    @config_files.collect{ |config_file| config_file.filename }
  end

  # When element_id contains a single, non-enumerable value, such as a String or Integer, then this
  # method returns that value directly rather than the ConfigElement representing the value.
  # It's an error to call this method to retrieve ConfigElements that express Hash and Array values.
  # A BadConfigDataFormat exception will be raised in that case.
  def [](element_id)
    e = element(element_id)
    if e.nil?
      nil
    else
      if e.has_children?
        raise BadConfigDataFormatException.new(e, "The element '#{element_id}' has children. It must be accessed via the 'element' method.")
      end

      e.value
    end
  end

  # Returns a ConfigElement instance for the given element id, or nil if no element with that id
  # exists.
  def element(element_id)
    @config_files.each do |config_file|
      if config_file.has_element?(element_id)
        return config_file[element_id]
      end
    end

    nil
  end

  # Gets the first element of the given id from the file set, and throws an exception if it's missing
  # or not of the required type.
  def ensure_kindof(element_id, *class_types)
    element = element(element_id)

    if element.nil?
      raise MissingConfigDataException.new(element_id)
    end

    element.ensure_kindof(*class_types)
  end

  # As for 'element', but raises a MissingConfigDataException if the element id isn't found.
  def get_mandatory(element_id)
    if !has_element?(element_id)
      raise MissingConfigDataException.new(element_id)
    end

    element(element_id)
  end

  # Returns true if an element with the given id exists.
  def has_element?(element_id)
    element(element_id).nil? == false
  end
end
