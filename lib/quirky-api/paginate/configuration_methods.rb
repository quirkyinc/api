module QuirkyApi
  module Paginate
    module ConfigurationMethods
      extend ActiveSupport::Concern
      module ClassMethods
        # Allows the model to override the default limit on returned items.
        def paginate_limit(val)
          @_default_limit = val
        end

        # Returns the model's default limit, or an API standard default.
        def default_limit
          (defined?(@_default_limit) && @_default_limit) || 20
        end

        # Allows the model to override the default max limit on returned items.
        def paginate_max_limit(val)
          @_default_max_limit = val
        end

        # Returns the models' default max limit, or an API standard default.
        def default_max_limit
          (defined?(@_default_max_limit) && @_default_max_limit) || 50
        end

        # Allows the model to override the default order of returned items.
        def paginate_order(val)
          order = val.split(' ')
          @_default_order_column = order[0]
          @_default_order_direction = order[1] if order[1] && %w(ASC DESC).include?(order[1].upcase)
        end

        # Returns the model's default order column, or an API standard default.
        def default_order_column
          (defined?(@_default_order_column) && @_default_order_column) || 'created_at'
        end

        # Returns the model's default order direction, or an API standard default.
        def default_order_direction
          (defined?(@_default_order_direction) && @_default_order_direction) || 'ASC'
        end

        # Returns a filtered order column for a query.
        def query_order(order_column = nil, order_direction = nil)
          order_column ||= default_order_column
          order_direction ||= default_order_direction

          # Make sure our order_column is a valid model attribute.
          raise QuirkyApi::Paginate::InvalidPaginationOptions, "attribute '#{order_column}' does not exist" unless model_attributes.include?(order_column)

          # Ensure our order_column includes the table name.
          order_column = "#{self.base_class.table_name}.#{order_column}" unless order_column.match(/^\w+\.\w+$/)

          [order_column, order_direction]
        end

        protected

        def model_attributes
          @model_attributes ||= begin
            attributes = self.base_class.column_names
            attributes.concat(self.base_class.stored_attributes.values)
            attributes.flatten!
            attributes
          end
        end
      end
    end
  end
end
