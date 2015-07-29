require 'quirky-api/paginate/configuration_methods'
require 'quirky-api/paginate/metadata_methods'
require 'quirky-api/paginate/sanitize_params'

# This is strongly influence by the Kaminari gem and their method of patching
# new methods onto ActiveRecord models, credit to them for this pattern and many
# others used in QuirkyApi::Paginate.
module QuirkyApi
  module Paginate
    module ActiveRecordExtension
      extend ActiveSupport::Concern

      module ClassMethods
        def inherited(kls)
          super
          kls.send(:include, QuirkyApi::Paginate::ActiveRecordModelExtension) if kls.superclass == ::ActiveRecord::Base
        end
      end

      included do
        self.descendants.each do |kls|
          kls.send(:include, QuirkyApi::Paginate::ActiveRecordModelExtension) if kls.superclass == ::ActiveRecord::Base
        end
      end
    end

    module ActiveRecordModelExtension
      extend ActiveSupport::Concern

      included do
        self.send(:include, QuirkyApi::Paginate::ConfigurationMethods)

        def self.paginate(params={})
          scope = self
          options = QuirkyApi::Paginate::SanitizeParams.new(params)

          # If the limit passed by the user is greater than we allow, reduce it to the max.
          limit = options.limit > default_max_limit ? default_max_limit : options.limit

          # Apply the user-provided or default order to our query.
          order_column, order_direction = query_order(options.order_column, options.order_direction)
          scope = scope.reorder("#{order_column} #{order_direction}", "#{self.base_class.table_name}.id")

          # Check for an existing cursor and apply our highly specialized cursor WHERE statement.
          cursor_direction = (order_direction) == 'ASC' ? '>' : '<'
          if options.cursor.present?
            scope = scope.
              from(
                <<-SQL
                  #{self.base_class.table_name},
                  (SELECT #{order_column} AS value FROM #{self.base_class.table_name} WHERE id = #{options.cursor} LIMIT 1) AS cursor
                SQL
              ).where(
                <<-SQL
                  #{order_column} #{cursor_direction} cursor.value
                  OR (
                    #{self.base_class.table_name}.id #{cursor_direction} #{options.cursor} AND #{order_column} = cursor.value
                  )
                SQL
              )
          end

          # Return our final scoped query with metadata methods added.
          scope.limit(limit).extending do
            include QuirkyApi::Paginate::MetadataMethods
          end
        end
      end
    end
  end
end
