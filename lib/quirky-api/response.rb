# encoding: utf-8

module QuirkyApi
  # The response module handles response and status code methods for the API.
  module Response
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
    def respond_with(response, options = {})
      return if @performed_render
      return render(json: { data: nil }) if response.nil?

      # If there's an active model serializer to speak of, use it.
      # Otherwise, just render what we've got.
      data = if response.respond_to?(:active_model_serializer) &&
                response.try(:active_model_serializer).present?

               options[:params] = params
               options[:current_user] = current_user if defined? current_user

               serializer = response.active_model_serializer
               if serializer <= ActiveModel::ArraySerializer
                 serializer = QuirkyArraySerializer
               end

               @res = serializer.new(response, options)
               { data: @res.as_json(root: false) }
             else
               { data: response }
             end

      # Check for warnings if applicable.
      if !@res.blank? && QuirkyApi.warn_invalid_fields
        warnings = @res.warnings(params)
        data[:warnings] = warnings if warnings.present?
      end

      data.merge!(options[:elements]) if options[:elements].present?

      renderable = { json: data }
      renderable[:status] = options[:status] if options[:status].present?

      render renderable
    end

    # <tt>respond_as_json</tt> is the direct connection between API endpoints
    # and ActiveModel Serializer.  AMS is a gem that provides the same
    # functionality as our old sreializer, with better support and speed
    # improvements.
    #
    # <tt>respond_as_json</tt> expects only one argument: Either a hash or an
    # array of ActiveModel objects.
    #
    # ==== Options
    #
    # * <tt>data</tt> is the dataset that should be serialized and returned.
    #   This can be a hash, an array of data or a single object.
    #
    # * <tt>options</tt> is an optional hash of options for the data that will
    #   be serialized.  This currently passes around the request parameters but
    #   can include other necessary data for the serializers.
    #
    # ==== Examples
    #
    #   @ideations = Ideation.last(100)
    #   respond_as_json(@ideations)
    #   #=> { 'data' => [...ideations...] }
    #
    #   @votes = Vote.last(10)
    #   respond_as_json({
    #     ideations: @ideations,
    #     votes: @votes
    #   })
    #   #=> {
    #     "data": {
    #       "ideations": [...ideations...],
    #       "votes": [...votes...]
    #     }
    #   }}
    #
    # See +QuirkyArraySerializer+ and +QuirkySerializer+ for more information.
    #
    def respond_as_json(data={}, options={}, &block)
      return if @performed_render
      if block_given?
        options = data
        data = if options[:expires_in] && options[:key]
                 Rails.cache.fetch "#{options[:key]}-endpoint-data",
                                   expires_in: options[:expires_in] do
                   yield
                 end
               else
                 yield
               end
      end

      # Ensure we're passing around the request parameters.
      options[:params] = params
      options[:current_user] = current_user
      options[:request] = request

      options[:flatten] = true unless data.is_a?(Array) || data.is_a?(Hash)

      warn 'DEPRECATION WARNING: respond_as_json is deprecated.  ' \
           'Use respond_with instead.'

      response = get_cache_data(data, options)
      render json: response, status: 200
    end

    # Returns a 400 bad request response.
    def bad_request(e)
      error_response(e, 400)
    end

    # Returns a 401 unauthorized response.
    def unauthorized(e)
      error_response(e.message, 401)
    end

    # Returns a 404 not found response.
    def not_found(e)
      error_response(e.message, 404)
    end

    # Returns 409 (conflict) for not unique records.
    def not_unique(e)
      error_response(e.message, 409)
    end

    # Returns an error message.
    def error(e)
      error_response(e.message)
    end

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
      options = cursor_pagination_options.merge(options)
      last_object_id = objects.last.id
      if objects.is_a?(Array)
        start = objects.index { |obj| obj.id == options[:cursor].to_i }
        objects = objects.slice(start, start + per_page)
      else
        if options[:reverse]
          objects = objects.where('id <= ?', options[:cursor])
        else
          objects = objects.where('id >= ?', options[:cursor])
        end
        objects = objects.limit(options[:per_page]) if options[:per_page]
      end

      object_ids = objects.map(&:id).compact

      # If we are reverse sorting the objects, the cursor is the minimum id - 1 to point to the next object)
      # If we are sorting it regularly, the cursor is maximum id + 1 to point to the next object
      cursor = options[:reverse] ? object_ids.min - 1 : object_ids.max + 1

      # If we have reached the last object, cursor should be nil
      if options[:reverse] && cursor < last_object_id
        cursor = nil
      elsif !options[:reverse] && cursor > last_object_id
        cursor = nil
      end
      [objects, cursor]
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
        cursor: params[:cursor] || 1,
        reverse: false
      }
    end

    def excludeable(key)
      yield unless (params['exclude'] || []).include? key
    end

    def sanitize_params(klass, params)
      sanitizer = Api::V2::Sanitizers::Sanitizer.get_sanitizer(klass)
      sanitizer.sanitize(params)
    end

    # Error handlers

    def unknown_action
      respond_not_found
    end

    def param_invalid(e)
      respond_bad_request(e.message)
    end

    def record_invalid(e)
      respond_bad_request_with_errors(e.record.errors)
    end

    def respond_forbidden
      head :forbidden
      @performed_render = true
    end

    def respond_unauthorized(message = nil)
      if message
        error_response(message, 401)
      else
        head :unauthorized
      end
      @performed_render = true
    end

    def respond_not_found
      head :not_found
      @performed_render = true
    end

    def respond_bad_request_with_errors(errors)
      errors = translate_errors(errors)
      respond_bad_request(errors)
    end

    def respond_bad_request(errors)
      respond({ errors: errors }, 400)
    end

    def validate_multiple(objects)
      objects.each_with_object({}) do |obj, errors|
        if obj.invalid?
          matched = obj.to_s.match(/([A-Za-z0-9\-\_]*)\:([A-Za-z0-9\-\_]*)/)
          klass, oid = matched[1], matched[2]

          errors["#{klass}:#{oid}"] = translate_errors(obj.errors)
        end
      end
    end

    def translate_errors(errors)
      # Gets the model that has the errors.
      model = errors.instance_variable_get('@base')

      errors.each_with_object({}) do |(key, error), hsh|
        # Some nested attributes get a weird dot syntax.
        key = key.to_s.split('.').last if key.match(/\./)

        # Retrieves the full error and cleans it as necessary.
        full_message = if key.to_s == 'base'
                         error
                       else
                         col = model.class.human_attribute_name(key)
                         "#{col} #{error}"
                       end

        (hsh[key] ||= []) << full_message
      end
    end

    def respond(response, status = 200)
      render json: response, status: status,
             serializer: false, each_serializer: false
      @performed_render = true
    end

    protected

    # Returns an error with a status code.
    #
    # @param msg [String] The message to show up.
    # @param status [Fixnum] The status code to return.  Default is 400.
    def error_response(msg, status = 400)
      render json: { errors: msg }, status: status
    end

    # Serializes data and returns as a hash with root based off of options.
    # This method should not be called manually; See +respond_as_json+, above.
    #
    # ==== Options
    # * <tt>data</tt> - The data that should be serialized.
    # * <tt>opts</tt> - Options to send to the serializer.  At the moment this
    #   is only for passing parameters into the serializer.  +respond_as_json+
    #   sends the following hash so that the serializer can work with request
    #   params:
    #     { 'params' => params }
    # * <tt>options</tt> - If +options[:root]+ is a string, sets the root of the
    #   output as that string.  If +options[:root]+ is boolean false, shows no
    #   root for this data.
    def get_cache_data(data, options)
      if data.is_a?(Hash)
        data.each do |k, v|
          if v && v.respond_to?(:object) && v.object.present? && v.class.present? && v.class <= QuirkySerializer
            data[k] = v
          elsif (v.respond_to?(:object) && v.object.blank?) || v.blank?
            data[k] = []
          elsif v.class <= ActiveRecord::Base || (v.is_a?(Array) && v.first && v.first.class <= ActiveRecord::Base) || v.class <= CartItems
            data[k] = QuirkyArraySerializer.new([*v], options)
          # elsif v.class <= Money
          #   data[k] = MoneySerializer.serialize(v, options)
          else
            data[k] = v
          end
        end

        presentable = data
      else
        presentable = QuirkyArraySerializer.new([*data], options)
      end

      { 'data' => presentable }
    end
  end
end
