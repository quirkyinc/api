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

            append_meta(envelope(data), options).to_json
          end

          renderable = { json: response }
          renderable[:status] = options[:status] if options[:status].present?

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
               envelope(@serialized_data.as_json(root: false))
             else
               envelope(response)
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

      data = append_meta(data, options)

      renderable = { json: data }
      renderable[:status] = options[:status] if options[:status].present?

      render renderable
    end

    # <tt>append_meta</tt> automatically appends additioanl meta information to
    # the JSON response.  Options include:
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
    def append_meta(data, options)
      return data unless data.is_a?(Hash)

      # Check for warnings if applicable.
      if QuirkyApi.warn_invalid_fields
        if @serialized_data.present?
          warnings = @serialized_data.warnings(params)
          data[:warnings] = warnings if warnings.present?
        end
      end

      data.merge!(options[:elements]) if options[:elements].present?
      data.merge!(options[:paginated_meta]) if options[:paginated_meta].present?

      data
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

    def excludeable(key)
      yield unless (params['exclude'] || []).include? key
    end

    def sanitize_params(klass, params)
      sanitizer = Api::V2::Sanitizers::Sanitizer.get_sanitizer(klass)
      sanitizer.sanitize(params)
    end

    protected

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

      envelope(presentable)
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
