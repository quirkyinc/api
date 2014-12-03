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
        return [objects, nil, nil] if objects.empty?

        options = cursor_pagination_options.merge(options)
        last_id = objects.last.id

        if objects.is_a?(Array)
          start = objects.index { |obj| obj.id == options[:cursor].to_i }
          paged_objects = objects.slice(start, start + per_page)
        else
          id_field = options[:ambiguous_field] ? options[:ambiguous_field] : 'id'
          if options[:reverse]
            predicate = '<='
            first_id = objects.first.id
          else
            predicate = '>='
            first_id = 1
          end

          options[:cursor] ||= first_id

          paged_objects = objects.where("#{id_field} #{predicate} #{options[:cursor]}")
          paged_objects = paged_objects.limit(options[:per_page]) if options[:per_page]

          # If the cursor option was not sent in, we are retrieving the first set, and the previous cursor is nil
          # If the cursor option was sent in, we use that as the previous cursor, but will retrieve only objects
          if (options[:cursor]) == first_id
            prev_cursor = nil
          else
            previous_predicate = options[:reverse] ? '>' : '<'
            previous_objects = objects.where("#{id_field} #{previous_predicate} #{options[:cursor]}").reverse_order
            previous_objects = previous_objects.limit(options[:per_page]) if options[:per_page]
            prev_cursor = previous_objects.last.try(:id)
          end
        end

        object_ids = paged_objects.map(&:id).compact

        # If we are reverse sorting the objects, the cursor is the minimum id - 1 to point to the next object)
        # If we are sorting it regularly, the cursor is maximum id + 1 to point to the next object
        # This works even when the max + 1 or min - 1 id is not present as we run a >= or <= operation when
        # filtering records
        next_cursor = (options[:reverse] ? object_ids.min - 1 : object_ids.max + 1) rescue nil

        # If we have reached the last object, next_cursor should be nil
        if options[:reverse] && next_cursor && next_cursor < last_id
          next_cursor = nil
        elsif !options[:reverse] && next_cursor && next_cursor > last_id
          next_cursor = nil
        end

        [paged_objects, next_cursor, prev_cursor]
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
      # @param next_cursor [Integer] The next_cursor returned by +paginate_with_cursor+.
      # @param prev_cursor [Integer] The prev_cursor returned by +paginate_with_cursor+.
      # @param options [Hash] A hash of options that will overwrite +cursor_pagination_options+.
      # @param options[:url] [Array] An array of URL options that will be passed to +polymorphic_url+.
      #
      # @see #paginate_with_cursor
      # @see {http://api.rubyonrails.org/classes/ActionDispatch/Routing/PolymorphicRoutes.html#method-i-polymorphic_url polymorphic_url}
      #
      def cursor_pagination_headers(objects, next_cursor = nil, prev_cursor = nil, options = {})
        raise ArgumentError.new('options[:url] must be provided') unless options[:url]

        options = self.cursor_pagination_options.merge(options)
        url = options.delete(:url)

        link_headers = []
        link_headers << link_header(paginated_url(url, cursor: next_cursor), 'next') if next_cursor
        link_headers << link_header(paginated_url(url, cursor: prev_cursor), 'prev') if prev_cursor

        headers['Link'] = link_headers.join(', ') if !link_headers.empty?
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
