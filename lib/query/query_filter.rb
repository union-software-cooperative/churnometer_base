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
    @filter_terms ||= QueryFilterTerms.new(@filter_xml)
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
  def initialize(filter_xml)
    xml = Nokogiri::XML(filter_xml)

    @terms = Hash.new([].freeze)

    xml.xpath('//search').children.each do |term|
      ary = 
        if @terms.has_key?(term.name)
          @terms[term.name]
        else
          new_ary = []
          @terms[term.name] = new_ary
          new_ary
        end

      ary << term.children.first.text
    end
  end

  # Returns an array of strings for the given filter term, or an empty array if the term isn't available.
  def [] (filter_term_name)
    @terms[filter_term_name]
  end
end
