class ApiAdapter
  attr_accessor :data, :options

  def initialize(data, options)
    @data = data
    @options = options
  end

  def call
    raise 'You must implement your own #call method in your subclass.'
  end
end
