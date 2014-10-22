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
    def respond_with(response, options = {})
      return if @performed_render

      @api_response_envelope = if options.key?(:envelope)
                                 options[:envelope]
                               else
                                 QuirkyApi.envelope
                               end

      return render(json: envelope(nil)) if response.nil?

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
               envelope(@res.as_json(root: false))
             else
               envelope(response)
             end

      # Check for warnings if applicable.
      if !@res.blank? && QuirkyApi.warn_invalid_fields && data.is_a?(Hash)
        warnings = @res.warnings(params)
        data[:warnings] = warnings if warnings.present?
      end

      if data.is_a?(Hash) && options[:elements].present?
        data.merge!(options[:elements])
      end

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
