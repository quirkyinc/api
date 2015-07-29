module QuirkyApi
  module Paginate
    module MetadataMethods
      def paginated_metadata
        {
          total: total_count,
          limit: limit_value,
          total_pages: total_pages,
          cursor: cursor,
          has_next_page: false,
          has_previous_page: false
        }
      end

      # Ref: https://github.com/amatsuda/kaminari/blob/715e5f89daeb5c13de0dc7aeff7959f9e6ac7abd/lib/kaminari/models/active_record_relation_methods.rb#L12-L31
      def total_count(column_name = :all, options = {}) #:nodoc:
        # #count overrides the #select which could include generated columns referenced in #order, so skip #order here, where it's irrelevant to the result anyway
        @total_count ||= begin
          c = except(:offset, :limit, :order)

          # Remove includes only if they are irrelevant
          c = c.except(:includes) unless references_eager_loaded_tables?

          # Rails 4.1 removes the `options` argument from AR::Relation#count
          args = [column_name]
          args << options if ActiveRecord::VERSION::STRING < '4.1.0'

          # .group returns an OrderdHash that responds to #count
          c = c.count(*args)
          if c.is_a?(Hash) || c.is_a?(ActiveSupport::OrderedHash)
            c.count
          else
            c.respond_to?(:count) ? c.count(*args) : c
          end
        end
      end

      def total_pages
        @total_pages ||= (total_count.to_f / limit_value).ceil
      end

      def cursor
        @cursor ||= last.id
      end
    end
  end
end
