##
# This is a base Adapter class for API response adapters.  It is not necessary,
# but it does offer access to the +data+ and +options+ attributes in your
# custom +call+ methods.
#
# If you wish, extend ApiAdapter in your custom adapter and create a +call+
# method, which will be able to manipulate the data that is returned in the
# JSON response.  The only pre-requisite is that the +call+ method must
# return a value that can be further altered on its way to proper response.
#
# If you want to use a custom adapter, you must ensure it is configured in your
# +QuirkyApi.configure+ block.  You can use +config.adapters.insert_before+,
# +config.adapters.insert_after+ or +config.adapters.use+, exactly like you
# would with Middleware.  Note: By default, +config.adapters.use+ will insert
# your adapter immediately before the +envelope+ adapter, because +envelope+
# will mutate the data into a harder-to-modify object.
#
# @example
#   # The below example will show a 'meta' object below the rest of the data,
#   # with 'status: 418' within it.
#   class FakeResponseStatusAdapter < ApiAdapter
#     def call
#       data[:meta] = { status: 418 }
#     end
#   end
#
#   # ...in your config file
#   QuirkyApi.configure do |config|
#     config.adapters.use FakeResponseStatusAdapter
#   end
#
class ApiAdapter
  attr_accessor :data, :headers, :options

  def initialize(data, options)
    @data = data
    @headers = options.fetch(:headers, {})
    @options = options
  end

  # This is a stub method to show that you can (and should) have a +call+
  # method in your custom adapter.  The call method is executed for each
  # configured adapter, and has the ability to mutate response data or
  # options sent forward to the final response (like status).  This method
  # must return data that can be further mutated.
  def call
    raise 'You must implement your own #call method in your subclass.'
  end

  # def finalize(renderable)
  #   # This is just a stub method to show that you can have a +finalize+
  #   # method in your custom adapter.  The +finalize+ method will be run
  #   # after data has been mutated, and just before the data is actually
  #   # rendered to the front-end.
  #   #
  #   # Your custom +finalize+ method is sent the +renderable+ hash, which
  #   # eventually will be passed to +render+ in order to provide the response.
  #   # Therefore, the result of this should return a Ruby Hash that is
  #   # understandable by the +render+ method.
  # end
end
