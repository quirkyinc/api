# encoding: utf-8

# Allows configuration for the QuirkyApi module.
module QuirkyApi
  class << self
    attr_accessor :validate_associations, :warn_invalid_fields, :auth_system,
                  :show_exceptions, :exception_handler, :envelope,
                  :pretty_print, :jsonp, :adapters

    def has_auth_system?
      auth_system.present? && auth_system.is_a?(Module)
    end

    def pretty_print
      @pretty_print.nil? ? true : @pretty_print
    end

    def pretty_print?
      pretty_print === true
    end

    def jsonp
      @jsonp.nil? ? true : @jsonp
    end

    def jsonp?
      jsonp === true
    end

    def adapters
      AdapterConfig.instance
    end

    def configure
      yield(self)
    end

    class AdapterConfig
      include Singleton

      attr_accessor :adapters

      def initialize
        @adapters ||= []
      end

      def all
        @adapters
      end

      def inspect
        @adapters
      end

      def use(new_adapter)
        insert_before EnvelopeAdapter, new_adapter
      end

      def insert_before(adapter, new_adapter)
        @adapters << {
          position: adapter,
          operation: '-1',
          adapter: new_adapter
        }
      end

      def insert_after(adapter, new_adapter)
        @adapters << {
          position: adapter,
          operation: '+1',
          adapter: new_adapter
        }
      end
    end
  end
end

