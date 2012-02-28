class DataPresenter
  attr_reader :data
  
  include Enumerable
  
  def initialize(data)
    @data = data
  end

  # Properties
  
  def has_data?
    data && data.count > 0
  end
  
  def interval_selections
    [
      ["none", "Off"],
      ["week", "Weekly"],
      ["month", "Monthly"],
    ]
  end
  
  # Wrappers
  
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