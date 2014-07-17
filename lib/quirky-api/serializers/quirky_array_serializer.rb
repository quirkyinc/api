# encoding: utf-8

# The +QuirkyArraySerializer+ handles serialization of arrays of data.
# QuirkyArraySerializer will find the serializer for each element in the array,
# run it on that element, and return the array with serialized data.
#
# @example
#   QuirkyArraySerializer.new(@items.all).as_json(root: false)
#   #=> [{ "id": 1, "name": "one" }, { "id": 2, "name": "two" }, ...]
class QuirkyArraySerializer < ::ActiveModel::ArraySerializer
  attr_accessor :params, :serializer_options
  def initialize(object, options = {})
    super(object, options)

    @serializer_options = options
    @params = options[:params] || {}
    @request = options[:request] || {}
    # More quirky-specific configuration can go here.
  end
end
