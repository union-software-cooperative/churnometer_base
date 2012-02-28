class DataPresenter
  attr_reader :data
  
  include Enumerable
  
  def initialize(data)
    @data = data
  end
  
  def each(&block)
    data.each &block
  end
  
  def count
    data.count
  end
  
  def [](index)
    data[index]
  end
  
end