module QuirkyApi
  module Paginate
    class SanitizeParams
      attr_accessor :offset, :limit, :cursor, :order_column, :order_direction

      def initialize(params={})
        unless params.is_a? ActiveSupport::HashWithIndifferentAccess
          params = ActiveSupport::HashWithIndifferentAccess.new(params)
        end

        self.offset = params[:offset]
        self.limit = params[:limit]
        self.cursor = params[:cursor]
        self.order = params[:order]
      end

      def offset=(offset)
        @offset = offset.to_i
      rescue NoMethodError
        @offset = 0
      end

      def limit=(limit)
        @limit = nonzero_integer(limit.to_i)
      rescue NoMethodError
        @limti = 10
      end

      def cursor=(cursor)
        @cursor = cursor.to_i > 0 ? cursor.to_i : nil
      rescue NoMethodError
        @cursor = nil
      end

      # We expect order to be in the form "<column_name> <direction>" OR "<column_name>"
      def order=(order)
        return nil unless order.kind_of?(String)

        # Split order on ' ' and grab column.
        sort = order.split(' ')
        @order_column = sort[0]

        # Check for a valid direction
        if sort[1]
          @order_direction = case sort[1]
            when 'ASC' 'asc' then 'ASC'
            when 'DESC' 'desc' then 'DESC'
            else 'ASC'
          end
        end
      end

      private

      def nonzero_integer(num, default=10)
        return default if num == 0
        num
      end
    end
  end
end
