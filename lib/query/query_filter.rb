require './lib/query/query_memberfact'

# A query of Churnometer data that makes use of filtering by dimension.
class QueryFilter < QueryMemberfact
  def initialize(db, filter_terms)
    super(db)
    @filter_terms = filter_terms
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
  # header1 is the groupby term for the current query.
  def modified_filter_for_site_constraint(filter_terms, site_constraint, start_date, end_date, header1)
    if site_constraint.empty?
      filter_terms
    else
      modified_filter = QueryFilterTerms.new

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
      site_query = QuerySitesAtDate.new(@churn_db, header1, dte, filter_terms())
      site_results = site_query.execute

      if site_results.num_tuples == 0
        modified_filter.append('companyid', 'none', false)
      else
        site_results.each do |record| 
          modified_filter.append('companyid', record['companyid'], false)
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

  attr_reader :name
  attr_accessor :values
  attr_accessor :exclude_values

  # If set, then this value is used as the column name when generating sql statements for the filter term.
  attr_accessor :db_column_override

  def initialize(name)
    @name = name.downcase
    @values = []
    @exclude_values = []
  end

  # Provide deep copies of filter terms.
  def clone
    copy = self.class.new(@name.dup)
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
      @name
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
class QueryFilterTerms
  include Enumerable

  # Creates an instance from the HTTP request's filter parameter hash.
  # The hash should be only the "filter" part of the request hash, not the complete request hash with
  # all other parameters present.
  def self.from_request_params(parameter_hash)
    instance = self.new
    instance._from_request_params(parameter_hash)
    instance
  end

  # Creates an instance from copies of the given FilterTerm instances.
  def self.from_terms(filter_terms)
    instance = self.new
    instance._from_terms(filter_terms)
    instance
  end

  def initialize
    # The default object for the Hash is an empty filter term called 'undefined'.
    @undefined_term = FilterTerm.new('undefined').freeze
    @terms = {}
  end

  # Returns a FilterTerm instance for the given filter name, or the 'unassigned' FilterTerm object if the term isn't available.
  def [] (filter_term_name)
    @terms.fetch(filter_term_name.downcase, @undefined_term)
  end

  # Replaces a filter term instance with a copy of the given FilterTerm instance, or adds the term if not
  # already present.
  def set_term(filter_term)
    @terms[filter_term.name] = filter_term.clone
  end

  # Returns FilterTerm instances describing the filter terms.
  def terms
    @terms.values
  end

  # Adds a value for the given filter term. Creates the term if it doesn't exist.
  # If 'exclude' is true, then the value should be excluded from search results.
  def append(filter_term_name, value, exclude)
    term = @terms[filter_term_name.downcase] ||= FilterTerm.new(filter_term_name)

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

  def _from_terms(filter_terms)
    filter_terms.each do |term|
      @terms[term.name] = term.dup
    end
  end

  def _from_request_params(parameter_hash)
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

        append(key, value, is_exclude)
      end
    end
  end
end
