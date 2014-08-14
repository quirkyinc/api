module QuirkyApi
  # Global methods are methods that are available to the default application,
  # as well as the API controllers.
  module Global
    # Runs the +serializer+ on the given +object+, and passes +options+ into
    # that serializer.  This method will also automatically include
    # +current_user+ and +params+, ala +respond_with+.
    #
    # @param object [Object] The object to serialize.  This must respond to
    #                        +active_model_serializer+ for serialization.
    # @param serializer [Object|nil] (Optional) The serializer to use when
    #                                serializing the object.  If blank or nil,
    #                                this method will attempt to figure out the
    #                                serializer on its own.
    # @param options [Hash] (Optional) A hash of options to pass into the
    #                                  serializer.  This method will
    #                                  automatically include +current_user+ and
    #                                  +params+ in the options.
    #
    # @example
    #   render json: { invention: serialize(Invention.last) }
    #   #=> {
    #         "invention": {
    #           "id": "1",
    #           "title": "...",
    #           ...
    #         }
    #       }
    #
    #   render json: { inventions: serializer(Invention.all) }
    #   #=> {
    #         "inventions": [
    #           {
    #             "invention": {
    #               "id": "1",
    #               "title": "...",
    #               ...
    #             }
    #           },
    #           {
    #             "invention": {
    #               "id": "2",
    #               "title": "...",
    #               ...
    #             }
    #           }
    #         ]
    #       }
    def serialize(object, serializer = nil, options = {})
      serializer = QuirkySerializer.get_serializer(object) if serializer.blank?
      return if serializer.blank?

      options ||= {}
      options[:current_user] = current_user if defined? current_user
      options[:params] = params if defined? params

      serializer.new(object, options).as_json(root: false)
    end
  end
end
