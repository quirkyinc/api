# encoding: utf-8

require 'quirky-api/response/errors'
require 'quirky-api/response/pagination'

module QuirkyApi
  # The response module handles response and status code methods for the API.
  module Response
    include Errors
    include Pagination

    # Returns a JSON response for the API.
    #
    # @param response [Mixed Array|String|Hash|nil|Bool] The data to return.
    # @param options [Hash] A hash of options to apss along with the response.
    #                       These options will be passed into QuirkySerializer
    #                       for processing.
    #
    # @example
    #   # Will return an array of data.
    #   respond_with Item.all
    #
    #   # Will return a single hash.
    #   respond_with Item.last
    #
    #   # Will return boolean 'true'
    #   respond_with true
    #
    #   # Will return a hash
    #   respond_with({
    #     my_name: 'Mike'
    #   })
    #
    # All responses will contain a 'data' key, wrapping all information:
    #
    #     {
    #        "data": {
    #           "id": 1,
    #           "name": "Mike",
    #           "last": "Sea"
    #         }
    #     }
    def respond_with(response, options = {}, &block)
      return if @performed_render

      @api_response_envelope = if options.key?(:envelope)
                                 options[:envelope]
                               else
                                 QuirkyApi.envelope
                               end

      if block_given?
        options = response

        # Rails seems to have an issue with caching large objects +.as_json+.
        # As a result, we need to actively transform the output +.to_json+ in
        # order to properly cache it and not completely screw up the output.
        if options[:cache_key].present?
          # +expires_in+ is an optional setting for caches, so it's optional
          # here, too.
          cache_opts = {}
          cache_opts[:expires_in] = options[:expires_in] if options[:expires_in].present?

          # Use this option if you want to serialize your data automatically.
          options[:serialize] = false if options[:serialize].nil?

          cache_key = "#{options[:cache_key]}-api-endpoint"
          response = Rails.cache.fetch cache_key, cache_opts do
            data = if options[:serialize]
                     serialize(block.call)
                   else
                     block.call
                   end

            append_meta(data, options).to_json
          end

          renderable = build_json_response(response, options)

          render renderable
          return
        else
          response = yield
        end
      end

      # Make sure we serialize unless otherwise specified.
      options[:serialize] = true if options[:serialize].nil?

      return render(json: envelope(nil)) if response.nil?

      # If there's an active model serializer to speak of, use it.
      # Otherwise, just render what we've got.
      data = if response.respond_to?(:active_model_serializer) &&
                response.try(:active_model_serializer).present? &&
                options[:serialize] == true

               options[:params] = params
               options[:current_user] = current_user if defined? current_user

               serializer = response.active_model_serializer
               if serializer <= ActiveModel::ArraySerializer
                 serializer = QuirkyArraySerializer
               end

               @serialized_data = serializer.new(response, options)
               @serialized_data.as_json(root: false)
             else
               response
             end

      # Append paginated_meta to the response if any response objects has it
      if response.respond_to?(:each) && response.is_a?(Hash)
        paginated_meta = {}
        response.each do |key, value|
          if value.respond_to?(:paginated_meta) && value.paginated_meta.present?
            paginated_meta[key] = value.paginated_meta
          end
        end
        options[:paginated_meta] = {paginated_meta: paginated_meta} unless paginated_meta.empty?
      end

      renderable = prepare_response(data, options)

      render renderable
    end

    def excludeable(key)
      yield unless (params['exclude'] || []).include? key
    end

    protected

    # <tt>append_meta</tt> will wrap and append useful information to the
    # response.  This includes:
    #
    #   1. +elements+ specified in the endpoint.  +elements+ are top-level keys
    #      in the JSON response.  They are at the same level as the envelope.
    #   2. +warnings+ are things that are were technically incorrect in the
    #      serialization of data.  These are problems that are not breaking,
    #      but you should be aware of.  This will only show up if you specify
    #      +config.warn_invalid_fields+ in your configure block.
    #   3. +paginated_meta+ is information about our custom pagination
    #      implementation.
    #
    # @param [Object] data   The data that should be processed, passed directly
    #                        from +respond_with+.  If this is an array, and
    #                        there is no envelope, no meta will be added.
    # @param [Hash] options  A hash of options, passed directly from
    #                        +respond_with+, which configure how the response
    #                        will appear.
    #
    # @example
    #   # With a default envelope of 'data'
    #   response = { id: 1, name: 'Mike Sea' }
    #   append_meta(response, options)
    #   #=> { data: { id: 1, name: 'Mike Sea' } }
    #
    #   # With no envelope
    #   response = [{ id: 1, name: 'Mike Sea' }, { id: 2, name: 'Bob Tester' }]
    #   append_meta(response, options)
    #   #=> [{ id: 1, name: 'Mike Sea' }, { id: 2, name: 'Bob Tester' }]
    #
    def append_meta(data, options = {})
      # Allow the envelope to be configurable from within the options.
      # +options+ here are passed all the way from +respond_with+, so you can
      # specify the envelope in your endpoint, for example:
      #
      # @example
      #   respond_with User.last, envelope: 'user'
      #
      @api_response_envelope = options[:envelope] if options[:envelope].present?

      # Because JSONP responses wrap the response within a function, we append
      # extra meta information to the response so we get essentially the same
      # results as if we made a request with AJAX or something.  JSONP
      # responses *must* be wrapped in an envelope so that the meta information
      # can be passed forward.
      #
      # Using JSONP means that the response will always return 200 (OK), and
      # you should use the meta 'status' attribute to retrieve the actual
      # status code.
      callback = params[:callback].presence || options[:callback]
      if QuirkyApi.jsonp? && callback.present?
        # JSONP responses must be wrapped in an envelope so there can be meta information.
        @api_response_envelope = 'data' if @api_response_envelope.blank?
        (options[:elements] ||= {}).merge!(meta: { status: options[:status].presence || 200 })
      end

      # Envelope the data, if applicable.  In the event of a JSONP response,
      # the data will always be enveloped.
      data = envelope(data)

      # Further changes would be impossible if the data was not already a hash.
      return data unless data.is_a?(Hash)

      # Check for warnings if applicable.
      if QuirkyApi.warn_invalid_fields
        if @serialized_data.present?
          warnings = @serialized_data.warnings(params)
          data[:warnings] = warnings if warnings.present?
        end
      end

      # +elements+ are top level keys in the JSON response, appearing at the
      # same level as the envelope for data.  You can specify as many elements
      # as you want, so long as they are a hash.
      data.merge!(options[:elements]) if options[:elements].present?

      # Paginated meta is information returned from our custom implementation
      # of pagination.
      data.merge!(options[:paginated_meta]) if options[:paginated_meta].present?

      # If configured, we pretty JSON responses.  This is the default response.
      data = JSON.pretty_generate(data) if QuirkyApi.pretty_print?

      data
    end

    # <tt>build_json_response</tt> prepares and returns the actual object that
    # will be passed to +render+, and in turn actually rendered as JSON.
    #
    # If there is a callback specified, and JSONP support is enabled, the
    # status code will always be +200 (OK)+, and the 'real' status code will be
    # passed as an attribute in the +meta+ hash, built in +append_meta+.  This
    # will also pass the callback to +render+, which automatically handles
    # JSONP responses.
    #
    # If this is not a JSONP request, you can specify the status code as an
    # option of +respond_with+, in order to change the status code of the
    # response.  Example:
    #
    #   respond_with(User.first, status: 201)
    #   #=> Responds with the first user, with status code '201 (Created)'.
    #
    # @param [Object] data   The data that should be processed, passed directly
    #                        from +respond_with+.  If this is an array, and
    #                        there is no envelope, no meta will be added.
    # @param [Hash] options  A hash of options, passed directly from
    #                        +respond_with+, which configure how the response
    #                        will appear.
    #
    def build_json_response(data, options = {})
      renderable = { json: data }

      # As described above, if this is a JSONP response, we respond 200 (OK)
      # and specify the callback to +render+.  Otherwise, we use the default
      # status code.
      callback = params[:callback].presence || options[:callback]
      if QuirkyApi.jsonp? && callback.present?
        renderable[:callback] = callback
        renderable[:status] = 200
      else
        renderable[:status] = options[:status] if options[:status].present?
      end

      renderable
    end

    # <tt>prepare_data</tt> is the final step before objects are displayed as
    # JSON in the API.  This method will append warnings, elements and
    # paginated_data to the response if possible, and 'prettify' the JSON
    # output if configured.
    #
    #   - +warnings+ are issues that the serializer encountered while
    #     serializing the object(s).  +warnings+ are usually syntax errors
    #     or incorrect field names, and will not adversely affect the response.
    #
    #   - +elements+ are top level keys that live outside of the 'envelope', if
    #     configured.  +elements+ must be passed as a hash.
    #
    #   - +paginated_meta+ is a top level key with the meta returned by the paginated method,
    #     if configured.  +paginated_meta+ must be passed as a hash.
    #
    # Both warnings and elements will *only* show up if the response is a hash.
    # They do not know how to react if the response is an array (e.g., if there
    # is no 'envelope' configured.)
    #
    def prepare_response(data, options = {})
      data = append_meta(data, options)
      build_json_response(data, options)
    end

    private

    # Envelopes data based on +QuirkyApi.envelope+.
    #
    # @param data [Object] Any type of object.
    #
    # @return [Hash] The enveloped data, if applicable.
    def envelope(data)
      return data if @api_response_envelope.blank?
      { @api_response_envelope.to_s => data }
    end
  end
end
