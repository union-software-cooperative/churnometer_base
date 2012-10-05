require './lib/query/query_memberfact'

# A query of Churnometer data that makes use of filtering by dimension.
class QueryFilter < QueryMemberfact
  def initialize(churnometer_app, db, filter_terms)
    super(db)
    @filter_terms = filter_terms
    @app = churnometer_app
  end

protected
  attr_reader :filter_terms

  # Generates a string of blocks of SQL text, expressing WHERE clauses that can be used to filter 
  # Churnometer data.
  # The clauses are connected with 'and' terms.
  #
  # Pass 'true' for is_appending if the text is intended to be appended to terms in an existing where clause.
  # An initial 'and' is prepended in that case where appropriate.
  def sql_for_filter_terms(filter_terms, is_appending)
    valid_terms = filter_terms.reject { |term| term.empty? }

    term_sqls = []

    filter_terms.terms.each do |term|
      if !term.values.empty?
        has_unassigned = term.values.include?('unassigned')

        result = "(coalesce(#{db().quote_db(term.db_column)},'') = any (#{db().sql_array(term.values, 'varchar')})"

        if has_unassigned
          result << " or (coalesce(#{db().quote_db(term.db_column)},'') = ''))"
        else
          result << ")"
        end
        
        term_sqls << result
      end

      if !term.exclude_values.empty?
        has_unassigned = term.values.include?('unassigned')

        result = "(not coalesce(#{db().quote_db(term.db_column)},'') = any (#{db().sql_array(term.exclude_values, 'varchar')})"

        if has_unassigned
          result << " or (not coalesce(#{db().quote_db(term.db_column)},'') = ''))"
        else
          result << ")"
        end
        
        term_sqls << result
      end
    end

    result_string = term_sqls.join("\n\tand ")

    if is_appending && !result_string.empty?
      "and " + result_string
    else
      result_string
    end
	end

  # Returns filter terms modified as appropriate given the supplied site constraint.
  # site_constraint should be empty, 'start' or 'end'.
  # start_date, end_date are the start and end date under consideration for the current query.
  def modified_filter_for_site_constraint(
     filter_terms, 
     site_constraint, 
     start_date, 
     end_date)

    if site_constraint.empty?
      filter_terms
    else
      modified_filter = FilterTerms.new

      # return the results for sites found at either the end of the beginning of this selection
      # this is a way of ruling out the effect of transfers, to determine what the targets should be
      # for sites as currently held (end_date) or held at the start (start_date)
      dte = 
        if site_constraint == 'start'
          start_date
        else
          end_date + 1
        end
      
      # override the filter to be sites as at the start or end
      work_site_dimension = @app.work_site_dimension

      site_query = QuerySitesAtDate.new(@app, @churn_db, dte, filter_terms())
      site_results = site_query.execute

      if site_results.num_tuples == 0
        modified_filter.append(work_site_dimension, 'none', false)
      else
        site_results.each do |record| 
          modified_filter.append(work_site_dimension, record[work_site_dimension.column_base_name], false)
        end
      end

      # keep original status filter
      modified_filter.set_term(filter_terms()['status'])
      
      modified_filter
    end
  end
end

class FilterTerm
  include Enumerable

  attr_reader :dimension
  attr_accessor :values
  attr_accessor :exclude_values

  # If set, then this value is used as the column name when generating sql statements for the filter term.
  attr_accessor :db_column_override

  def initialize(dimension)
    @dimension = dimension
    raise "A Dimension instance must be supplied." if !@dimension.kind_of?(Dimension)
    @values = []
    @exclude_values = []
  end

  # Provide deep copies of filter terms.
  def clone
    copy = self.class.new(@dimension)
    copy.values = @values.dup
    copy.exclude_values = @exclude_values.dup
    copy.db_column_override = @db_column_override.dup if @db_column_override
    copy
  end

  # The database column that the filter refers to.
  def db_column
    if @db_column_override 
      @db_column_override
    else
      @dimension.column_base_name
    end
  end

  # True if values and exclusive values are empty.
  def empty?
    @values.empty? && @exclude_values.empty?
  end
end

# Describes filtering of Churnometer query results.
#
# Filter term names are case-insensitive.
#
# Methods from Enumerable can be used to iterate over FilterTerm instances.
class FilterTerms
  include Enumerable

  # Creates an instance from the HTTP request's filter parameter hash.
  # The hash should be only the "filter" part of the request hash, not the complete request hash with
  # all other parameters present.
  # dimensions: The Dimensions instance containing all possible filterable dimensions.
  def self.from_request_params(parameter_hash, dimensions)
    instance = self.new
    instance._from_request_params(parameter_hash, dimensions)
    instance
  end

  # Creates an instance from copies of the given FilterTerm instances.
  def self.from_terms(filter_terms)
    instance = self.new
    instance._from_terms(filter_terms)
    instance
  end

  def initialize
    @terms = {}
  end

  def self.undefined_dimension
    @undefined_dimension ||= Dimension.new(-1)
  end

  def self.undefined_term
    # The default object for the Hash is an empty filter term called 'undefined'.
    @undefined_term ||= FilterTerm.new(undefined_dimension()).freeze
  end

  # Returns a FilterTerm instance for the given dimension, or nil if a term for the dimension 
  # isn't available.
  # For convenience, a dimension id can be specified instead of a Dimension instance.
  def [] (dimension_or_string)
    if dimension_or_string.kind_of?(String)
      @terms.values.find{ |term| term.dimension.id == dimension_or_string }
    else
      @terms[dimension]
    end
  end

  # Replaces a filter term instance with a copy of the given FilterTerm instance, or adds the term if not
  # already present.
  def set_term(filter_term)
    @terms[filter_term.dimension] = filter_term.clone
  end

  # Returns FilterTerm instances describing the filter terms.
  def terms
    @terms.values
  end

  # Adds a value for a filter term on the given dimension. Creates the term if it doesn't exist.
  # If 'exclude' is true, then the value should be excluded from search results.
  # dimension: Instance of a Dimension object.
  def append(dimension, value, exclude)
    term = @terms[dimension] ||= FilterTerm.new(dimension)

    target =
      if !exclude
        term.values
      else
        term.exclude_values
      end

    target << value
  end

  # :yields: |FilterTerm instance|
  def each(&block)
    @terms.values.each(&block)
  end

  # Returns a new FilterTerms object with only the dimensions with the given ids included.
  def include(*dimension_ids)
    included_terms = @terms.values.select { |term| dimension_ids.include?(term.dimension.id) }

    self.class.from_terms(included_terms)
  end

  # Returns a new FilterTerms object with the dimensions with the given ids excluded.
  def exclude(*dimension_ids)
    included_terms = @terms.values.reject { |term| dimension_ids.include?(term.dimension.id) }

    self.class.from_terms(included_terms)
  end

  def _from_terms(filter_terms)
    filter_terms.each do |term|
      @terms[term.dimension] = term.dup
    end
  end

  def _from_request_params(parameter_hash, dimensions)
    parameter_hash.each do |key, values|
      values = Array(values)
      
      values.each do |value|
        # If value is a string, then parse it to interpret any modifiers in the value.
        # Otherwise, just use the value. This conserves type information that arrives from the parameter
        # hash.
        is_exclude = nil

        if value.kind_of?(String)
          value_parse = /^([-!]?)(.+)/.match(value)
          
          value_modifier = value_parse[1]
          
          # values starting with '-' should be ignored.
          next if value_modifier == '-'
          
          is_exclude = value_modifier == '!'
          
          value = value_parse[2]
        else
          is_exclude = false
        end

        dimension = dimensions.dimension_for_id(key)

        raise "Unknown dimension '#{key}' given for filter term." if dimension.nil?
        
        append(dimension, value, is_exclude)
      end
    end
  end
end
