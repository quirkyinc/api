##
# The ResponseAdapter class handles the mutation, tidying and prettyfing of
# data before it is rendered in the response.  This class handles everything
# from JSONP support, to wrapping the data in an "envelope" (e.g. "data"),
# to pretty priting the final response.
#
# While this has a finite list of adapters used directly in the gem, you can
# easily make your own adapters to further adjust the API response.  See
# ApiController for further details on custom adapters.
#
module QuirkyApi
  module Response
    class ResponseAdapter
      # Requires files used for base adapters.
      require File.expand_path('../adapters/api_adapter', __FILE__)
      require File.expand_path('../adapters/jsonp_adapter', __FILE__)
      require File.expand_path('../adapters/envelope_adapter', __FILE__)
      require File.expand_path('../adapters/warnings_adapter', __FILE__)
      require File.expand_path('../adapters/elements_adapter', __FILE__)
      require File.expand_path('../adapters/paginated_meta_adapter', __FILE__)
      require File.expand_path('../adapters/pretty_print_adapter', __FILE__)

      # These are the adapters that Quirky Api uses to tidy and generate our
      # response.
      ADAPTERS = [
        JsonpAdapter,           # JSONP support.
        EnvelopeAdapter,        # Envelopes data (e.g.: 'test' becomes { data: 'test' })
        WarningsAdapter,        # Handles potential warnings due to invalid request fields.
        ElementsAdapter,        # Handles 'elements', or top-level keys in the JSON response.
        PaginatedMetaAdapter,   # Handles paginated meta for pagination.
        PrettyPrintAdapter      # "Prettifies" JSON response.
      ].freeze

      attr_accessor :data, :options
      attr_accessor :_finalize_adapters

      def initialize(data, options)
        @data = data
        @options = options
        @_finalize_adapters = []
      end

      # This method executes all configured adapters' call methods in order to
      # manipulate the response data.  By calling everything in order, we get
      # the final response.
      def call!
        # Get all adapters, inclusive of the ones listed above, and iterate
        # over them.
        configured_adapters.each do |adapter|
          # Instantiate a new instance of the adapter given the current data.
          a = adapter.new(@data, options)

          # If this particular adapter has a +finalize+ method (see below),
          # keep a record of its existence so we can call it later.
          @_finalize_adapters << adapter if a.respond_to?(:finalize)

          # Call the +call+ method in order to manipulate the response.
          @data = a.call
        end

        # Return the final response.
        @data
      end

      # finalize! is called after the response data has been manipulated,
      # before we actually call +render json: ...+ on it.  This method calls
      # the +finalize+ method on any adapter that has it (as determined above),
      # which in turn allows you to change things like response status, JSONP
      # callbacks, and so forth.
      #
      # Note: Your custom +finalize+ implementation must accept the
      # +renderable+ argument and return a Ruby Hash that the +render+ method
      # can understand.
      #
      # @param [Hash] The current object that will be called by +render+ when
      #               all is said and done.
      #
      def finalize!(renderable)
        # As determined above, get all adapters that implement a +finalize+
        # method and iterate over those adapters.
        @_finalize_adapters.each do |adapter|
          # Instantiate a new instance.  We do this to ensure that we
          # definitely have the latest data / options following data
          # manipulation by the +call!+ method.
          a = adapter.new(data, options)

          # Call +finalize+ on the adapter and set +renderable+ to its
          # response.
          renderable = a.finalize(renderable)
        end

        # Return the very final response object.  Just after this is called,
        # we call +render+ with this value.
        renderable
      end

      private

      # Retrieves all adapters, homegrown and custom, that will be used to
      # manipulate our response.
      def configured_adapters
        # Get our adapters as above.
        adapters = ADAPTERS.dup

        # Get all configured custom adapters and iterate over them.
        QuirkyApi.adapters.all.each do |configured_adapter|
          # Get the index of the adapter that will be used to determine
          # placement on the custom adapter.
          index = adapters.index(configured_adapter[:adapter])

          # Get the pre-existing adapter at that index.
          old_adapter = adapters[index]

          # Determine the placement of the new adapter by the 'placement'
          # specified when you configured it (based upon insert_before/after).
          # '+1' here means the new adapter should go after the old one, '-1'
          # means it should go before the old one.
          case configured_adapter[:placement]
          # Append
          when '+1'
            # Put the new adapter immediately after the old adapter.
            adapters[index, 1] = [old_adapter, configured_adapter[:new_adapter]]
          # Prepend
          when '-1'
            # Put the ne wadapter immediately before the old adapter.
            adapters[index, 1] = [configured_adapter[:new_adapter], old_adapter]
          end
        end

        # Return all adapters such as they are.
        adapters
      end
    end
  end
end
