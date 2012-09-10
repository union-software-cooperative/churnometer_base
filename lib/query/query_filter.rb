require './lib/query/query'

# A query of Churnometer data that makes use of filtering by dimension.
class QueryFilter < Query
protected
  # nokogiri_doc: a Nokogiri XML object
  def xml_array_to_array(xpath, nokogiri_doc)
    nokogiri_doc.xpath(xpath).children.collect { |textnode| textnode.text }
  end
end
