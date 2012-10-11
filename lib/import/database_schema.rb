# Stubbed out David's Dimensions class in preparation for
# integrating with his code and replacing this

class Dimension2
  attr_accessor :column_base_name
end

class Dimensions2
  include Enumerable
  
  attr_accessor :dimension_count
  
  def initialize
    @dimension_count = 25
  end
  
  def each(&block)
    @dimension_count.times do |i|
      d = Dimension.new
      d.column_base_name = "col#{i}"
      yield d
    end
  end
  
end