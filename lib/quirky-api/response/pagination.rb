module QuirkyApi
  module Response
    module Pagination
      # Paginates data.
      #
      # @param objects [Array|Object] The object(s) to paginate.
      # @param options [Hash] A hash of options that will
      #                       overwrite pagination_options.
      #
      # @see pagination_options
      def paginate(objects, options = {})
        options = self.pagination_options.merge(options)
        unless objects.is_a?(Array)
          objects.paginate(options)
        else
          objects[((options[:page].to_i - 1) * options[:per_page].to_i)...(options[:per_page].to_i * options[:per_page].to_i)] || []
        end
      end

      def paginate_with_cursor(objects, options = {})
        return [objects, nil] if objects.empty?
        options = cursor_pagination_options.merge(options)
        last_object_id = objects.last.id
        if objects.is_a?(Array)
          start = objects.index { |obj| obj.id == options[:cursor].to_i }
          objects = objects.slice(start, start + per_page)
        else
          id_field = options[:ambiguous_field] ? options[:ambiguous_field] : 'id'
          if options[:reverse]
            predicate = '<='
            options[:cursor] ||= objects.first.id
          else
            predicate = '>='
            options[:cursor] ||= 1
          end
          objects = objects.where("#{id_field} #{predicate} #{options[:cursor]}")
          objects = objects.limit(options[:per_page]) if options[:per_page]
        end

        object_ids = objects.map(&:id).compact

        # If we are reverse sorting the objects, the cursor is the minimum id - 1 to point to the next object)
        # If we are sorting it regularly, the cursor is maximum id + 1 to point to the next object
        next_cursor = (options[:reverse] ? object_ids.min - 1 : object_ids.max + 1) rescue nil

        # If we have reached the last object, next_cursor should be nil
        if options[:reverse] && next_cursor && next_cursor < last_object_id
          next_cursor = nil
        elsif !options[:reverse] && next_cursor && next_cursor > last_object_id
          next_cursor = nil
        end
        [objects, next_cursor]
      end

      # Default options for pagination.
      def pagination_options
        {
          per_page: params[:per_page] || 10,
          page: params[:page] || 1
        }
      end

      def cursor_pagination_options
        {
          per_page: params[:per_page] || 10,
          cursor: params[:cursor],
          reverse: false,
          ambiguous_field: nil
        }
      end
    end
  end
end
