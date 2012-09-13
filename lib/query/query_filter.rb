require './lib/query/query'

# A query of Churnometer data that makes use of filtering by dimension.
class QueryFilter < Query
  def initialize(db, filter_xml)
    super(db)
    @filter_xml = filter_xml
  end

protected
  attr_reader :filter_xml

  # Generates a string of blocks of SQL text, expressing WHERE clauses that can be used to filter 
  # Churnometer data.
  # The clauses are connected with 'and' terms.
  #
  # Pass 'true' for is_appending if the text is intended to be appended to terms in an existing where clause.
  # An initial 'and' is prepended in that case where appropriate.
  def sql_for_filter_terms(filter_terms, is_appending)
    valid_inclusive_terms = filter_terms.inclusive_terms.reject { |term| term.empty? }
    valid_exclusive_terms = filter_terms.exclusive_terms.reject { |term| term.empty? }

    term_sqls = valid_inclusive_terms.collect do |term|
      "(coalesce(#{db().quote_db(term.db_column)},'') = any (#{db().sql_array(term.values, 'varchar')}) or (coalesce(#{db().quote_db(term.db_column)},'') = '' and 'unassigned' = any (#{db().sql_array(term.values, 'varchar')})))"
    end
    
    term_sqls += valid_exclusive_terms.collect do |term|
      "(not coalesce(#{db().quote_db(term.db_column)},'') = any (#{db().sql_array(term.values, 'varchar')}) or (coalesce(#{db().quote_db(term.db_column)},'') = '' and not 'unassigned' = any (#{db().sql_array(term.values, 'varchar')})))"
    end

    result_string = term_sqls.join("\n\tand ")

    if is_appending && !result_string.empty?
      "and " + result_string
    else
      result_string
    end
	end

  # Returns filter terms for the xml initially supplied to the object.
  def filter_terms
    @filter_terms ||= QueryFilterTerms.from_xml(@filter_xml)
  end
end

class FilterTerm
  include Enumerable

  attr_reader :name
  attr_accessor :values

  def initialize(name)
    @name = name.downcase
    @values = []
  end

  # Provide deep copies of filter terms.
  def clone
    copy = self.class.new(@name.dup)
    copy.values = @values.dup
  end

  # The database column that the filter refers to.
  def db_column
    # Remove 'not_' from the start of the name string.
    @name.sub(/^not_/, '')
  end

  # Iterate over each value for the term.
  def each(&block)
    @values.each(&block)
  end

  def empty?
    @values.empty?
  end

  # Whether the term describes an exclusive criteria, meaning that the values in the filter should be 
  # excluded from the results when present in the data represented by the term name.
  def exclusive?
    @name.start_with?('not_')
  end 

  def hash
    @name.hash
  end
end

# Describes filtering of Churnometer query results.
# Given xml of the following format:
#
# <search>
#		<term1>any_text</term1>
#		<term1>any_other_text</term1>
#		<term2>more_text</term2>
# </search>
#
# Then the [] method of this class returns arrays of FilterTerms for the keys 'term1', 'term2', etc.
#
# Filter term names are case-insensitive.
class QueryFilterTerms
  include Enumerable

  def self.from_xml(filter_xml)
    instance = self.new
    instance.from_xml(filter_xml)
    instance
  end

  def self.from_terms(filter_terms)
    instance = self.new
    instance.from_terms(filter_terms)
    instance
  end

  def initialize
    # The default object for the Hash is an empty filter term called 'undefined'.
    @undefined_term = FilterTerm.new('undefined').freeze
    @terms = {}
  end

  # Creates an instance from copies of the given FilterTerm instances.
  def from_terms(filter_terms)
    filter_terms.each do |term|
      @terms[term.name] = term.dup
    end
  end

  def from_xml(filter_xml)
    xml = Nokogiri::XML(filter_xml)

    xml.xpath('//search').children.each do |term|
      # The 'Ignore Filter' option prepends terms with "ignore_". Those terms shouldn't be included.
      next if term.name.start_with?('ignore_')

      # As a side effect of removing a term, the controller provides an empty xml node for that term.
      if !term.children.empty?
        append(term.name, term.children.first.text)
      end
    end
  end

  # Returns a FilterTerm instance for the given filter name, or the 'unassigned' FilterTerm object if the term isn't available.
  def [] (filter_term_name)
    @terms.fetch(filter_term_name.downcase, @undefined_term)
  end

  # Replaces a set of filter term values with the given array. Creates the term if it doesn't exist.
  def []= (filter_term_name, value_array)
    term = @terms[filter_term_name.downcase] ||= FilterTerm.new(filter_term_name)

    term.values = value_array
  end

  # Returns FilterTerm instances describing the filter terms.
  def terms
    @terms.values
  end

  # Adds a value for the given filter term. Creates the term if it doesn't exist.
  def append(filter_term_name, value)
    term = @terms[filter_term_name.downcase] ||= FilterTerm.new(filter_term_name)

    term.values << value
  end

  # :yields: |FilterTerm instance|
  def each(&block)
    @terms.values.each(&block)
  end

  # Returns every 'exclusive' filter term (meaning values should be excluded from search results.)
  def exclusive_terms(&block)
    @terms.values.select{ |term| term.exclusive? }
  end

  # Returns every 'inclusive' filter term (meaning values should be included in search results.)
  def inclusive_terms(&block)
    @terms.values.select{ |term| !term.exclusive? }
  end

  # Returns a new FilterTerms object with only the given terms included.
  def include(*term_names)
    downcase_term_names = term_names.collect { |name| name.downcase }

    included_terms = @terms.values.select { |term| downcase_term_names.include?(term.name) }

    self.class.from_terms(included_terms)
  end

  # Returns a new FilterTerms object with the given terms excluded.
  def exclude(*term_names)
    downcase_term_names = term_names.collect { |name| name.downcase }

    included_terms = @terms.values.reject { |term| downcase_term_names.include?(term.name) }

    self.class.from_terms(included_terms)
  end
end
