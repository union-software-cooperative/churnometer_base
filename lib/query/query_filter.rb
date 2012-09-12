require './lib/query/query'

# A query of Churnometer data that makes use of filtering by dimension.
class QueryFilter < Query
  def initialize(db, filter_xml)
    super(db)
    @filter_xml = filter_xml
  end

protected
  attr_reader :filter_xml

  # Returns filter terms for the xml initially supplied to the object.
  def filter_terms
    @filter_terms ||= QueryFilterTerms.from_xml(@filter_xml)
  end
end

# Given xml of the following format:
#
# <search>
#		<term1>any_text</term1>
#		<term1>any_other_text</term1>
#		<term2>more_text</term2>
# </search>
#
# Then the [] method of this class returns arrays of the text for the keys 'term1', 'term2', etc.
class QueryFilterTerms
  def self.from_xml(filter_xml)
    instance = self.new
    instance.from_xml(filter_xml)
    instance
  end

  def initialize
    @terms = Hash.new([].freeze)
  end

  def from_xml(filter_xml)
    xml = Nokogiri::XML(filter_xml)

    xml.xpath('//search').children.each do |term|
      append(term.name, term.children.first.text)
    end
  end

  # Returns an array of strings for the given filter term, or an empty array if the term isn't available.
  def [] (filter_term_name)
    @terms[filter_term_name]
  end

  # Replaces a set of filter term values with the given filter array.
  def []= (filter_term_name, value_array)
    @terms[filter_term_name] = value_array
  end

  # Adds a value for the given filter term. Creates the term if it doesn't exist.
  def append(filter_term_name, value)
    ary = 
      if @terms.has_key?(filter_term_name)
        @terms[filter_term_name]
      else
        new_ary = []
        @terms[filter_term_name] = new_ary
        new_ary
      end
    
    ary << value
  end
end
