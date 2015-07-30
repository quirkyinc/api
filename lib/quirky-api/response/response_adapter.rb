module QuirkyApi
  module Response
    class ResponseAdapter
      require File.expand_path('../adapters/api_adapter', __FILE__)
      require File.expand_path('../adapters/jsonp_adapter', __FILE__)
      require File.expand_path('../adapters/envelope_adapter', __FILE__)
      require File.expand_path('../adapters/warnings_adapter', __FILE__)
      require File.expand_path('../adapters/elements_adapter', __FILE__)
      require File.expand_path('../adapters/paginated_meta_adapter', __FILE__)
      require File.expand_path('../adapters/pretty_print_adapter', __FILE__)

      ADAPTERS = [
        JsonpAdapter,
        EnvelopeAdapter,
        WarningsAdapter,
        ElementsAdapter,
        PaginatedMetaAdapter,
        PrettyPrintAdapter
      ].freeze

      attr_accessor :data, :options
      attr_accessor :_finalize_adapters

      def initialize(data, options)
        @data = data
        @options = options
        @_finalize_adapters = []
      end

      def call!
        configured_adapters.each do |adapter|
          a = adapter.new(@data, options)
          @_finalize_adapters << adapter if a.respond_to?(:finalize)
          @data = a.call
        end

        @data
      end

      def finalize!(renderable)
        @_finalize_adapters.each do |adapter|
          a = adapter.new(data, options)
          renderable = a.finalize(renderable)
        end

        renderable
      end

      private

      def configured_adapters
        adapters = ADAPTERS.dup

        QuirkyApi.adapters.all.each do |configured_adapter|
          case configured_adapter[:operation]
          when '+1'
            index = adapters.index(configured_adapter[:position])
            old_thing = adapters[index]
            adapters[index, 1] = [old_thing, configured_adapter[:adapter]]
          when '-1'
            index = adapters.index(configured_adapter[:position])
            old_thing = adapters[index]
            adapters[index, 1] = [configured_adapter[:adapter], old_thing]
          end
        end

        adapters
      end
    end
  end
end
