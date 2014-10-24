module QuirkyApi
  module Response
    module Pagination
      # Paginates data.
      #
      # @param objects [Array|Object] The object(s) to paginate.
      # @param options [Hash] A hash of options that will
      #                       overwrite +pagination_options+.
      #
      # @see pagination_options
      #
      def paginate(objects, options = {})
        options = self.pagination_options.merge(options)
        unless objects.is_a?(Array)
          objects.paginate(options)
        else
          objects[((options[:page].to_i - 1) * options[:per_page].to_i)...(options[:per_page].to_i * options[:per_page].to_i)] || []
        end
      end

      # Paginates data based on a cursor.
      #
      # @param objects [Array|Object] The object(s) to paginate.
      # @param options [Hash] A hash of options that will overwrite
      #                       +cursor_pagination_options+.
      #
      # @see cursor_pagination_options
      #
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

      # Sets Hypermedia-style Link headers for a collection of paginated objects.
      # See: https://developer.github.com/guides/traversing-with-pagination/
      #
      # @param objects [Object] A collection of objects that have been paginated by will_paginate.
      # @param options [Hash] A hash of options that will overwrite +pagination_options+.
      # @param options[:url] [Array] An array of URL options that will be passed to +polymorphic_url+.
      #
      # @see #pagination_options
      # @see {http://api.rubyonrails.org/classes/ActionDispatch/Routing/PolymorphicRoutes.html#method-i-polymorphic_url polymorphic_url}
      #
      def pagination_headers(objects, options = {})
        raise ArgumentError.new('options[:url] must be provided') unless options[:url]

        options = self.pagination_options.merge(options)
        url = options.delete(:url)
        link_headers = []

        if options[:page].to_i > 1
          link_headers << link_header(paginated_url(url, page: 1), 'first')
        end
        if objects.next_page
          link_headers << link_header(paginated_url(url, page: objects.next_page), 'next')
        end
        if objects.previous_page
          link_headers << link_header(paginated_url(url, page: objects.previous_page), 'prev')
        end
        if objects.total_pages != options[:page].to_i
          link_headers << link_header(paginated_url(url, page: objects.total_pages), 'last')
        end

        headers['Link'] = link_headers.join(', ') if link_headers.size
        headers['Total'] = objects.total_entries.to_s
      end

      # Sets Hypermedia-style Link headers for a collection of cursor-based paginated objects.
      #
      # @param objects [Object] The unscoped object(s) to paginate. Do not pass the same set of objects returned by +paginate_with_cursor+, the total will not be calculated correctly using those.
      # @param cursor [Integer] The cursor returned by +paginate_with_cursor+.
      # @param options [Hash] A hash of options that will overwrite +pagination_options+.
      # @param options[:url] [Array] An array of URL options that will be passed to +polymorphic_url+.
      #
      # @see #paginate_with_cursor
      # @see {http://api.rubyonrails.org/classes/ActionDispatch/Routing/PolymorphicRoutes.html#method-i-polymorphic_url polymorphic_url}
      #
      def cursor_pagination_headers(objects, cursor, options = {})
        raise ArgumentError.new('options[:url] must be provided') unless options[:url]

        options = self.cursor_pagination_options.merge(options)
        url = options.delete(:url)

        headers['Link'] = link_header(paginated_url(url, cursor: cursor), 'next') if cursor
        headers['Total'] = objects.count.to_s
      end

      # Default options for pagination.
      def pagination_options
        {
          per_page: params[:per_page] || 10,
          page: params[:page] || 1
        }
      end

      # Default options for cursor pagination.
      def cursor_pagination_options
        {
          per_page: params[:per_page] || 10,
          cursor: params[:cursor],
          reverse: false,
          ambiguous_field: nil
        }
      end

      private

      def paginated_url(url, options = {})
        exclude_params = options.keys + request.path_parameters.keys
        polymorphic_url(url, params: params.except(*exclude_params).merge(options))
      end

      def link_header(url, rel)
        "<#{url}>; rel=\"#{rel}\""
      end
    end
  end
end
