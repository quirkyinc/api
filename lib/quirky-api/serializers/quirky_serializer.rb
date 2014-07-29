# encoding: utf-8

# QuirkySerializer is Quirky's base serializer, providing functionality
# that inherits from and extends ActiveModel::Serializers.  All serializers
# that inherit from QuirkySerializer will receive the following (new)
# functionality:
#
# * Optional fields
# * Associations
# * Default associations
# * Request parameter parsing
# * Field inclusion
# * Field exclusion
# * Sub-associations (associations within associations)
# * Sub-fields (fields within associations)
#
# @example
#   class UserSerializer < QuirkyApi::QuirkySerializer
#     attributes :id, :name
#     optional :email
#     associations :avatar
#   end
#
class QuirkySerializer < ::ActiveModel::Serializer
  class << self
    attr_accessor :_optional_fields, :_associations,
                  :_default_associations, :_options

    # Optional fields assigned to this serializer.  Optional fields need to
    # be explicitly requested (by passing +extra_fields[]=field+) to be
    # returned in the payload.
    #
    # Optional fields will return warnings if configured, and the requester
    # asks for fields that do not exist in the serializer.
    #
    # @param fields [Array] A comma-separated list of fields that are optional.
    #
    # @example
    #   class UserSerializer < QuirkyApi::QuirkySerializer
    #     optional :email, :is_russian
    #   end
    #
    #   # Request like this: /api/v1/users/1?extra_fields[]=email
    def optional(*fields)
      self._optional_fields = fields
    end

    # Associations make it possible to associate a different model with the
    # requested one.  Associations must be explicitly requested (by passing
    # +associations[]=association+), UNLESS the requested association is
    # already a default association.
    #
    # @param associations [Array] A comma-separated list of associations.
    #
    # @example
    #   class UserSerializer < QuirkyApi::QuirkySerializer
    #     associations :profile
    #   end
    #
    #   # request like this: /api/v1/users/1?associations[]=profile
    #
    # @see default_associations
    def associations(*associations)
      self._associations = associations
    end

    # Default associations are associations that will show up in the payload,
    # regardless of whether or not you ask for them.  Default associations
    # are generally used for information that is requested more often than not.
    #
    # Default associations must be valid associations.
    #
    # @param default_associations [Array] A comma-separated list of associations
    #                                     that should always show up.
    # @example
    #   class UserSerializer < QuirkyApi::QuirkySerializer
    #     associations :profile, :avatar
    #     default_associations :profile
    #   end
    #
    # @see associations
    def default_associations(*default_associations)
      self._default_associations = default_associations
    end

    # Returns warnings about your request. Warnings are messages that alert
    # you to things that are wrong, but not breaking.  In this initial release,
    # warnings are only triggered by requesting optional fields that do not
    # exist in the serializer.
    #
    # Warnings will be returned as an array at the end of the payload with the
    # key 'warnings'.
    #
    # Warnings must be enabled through the +warn_invalid_fields+ configuration
    # option.
    #
    # @param params [Hashie] The params object that is passed around in Rails.
    #
    # @return [Array] An array of warnings.
    #
    # @example
    #   # GET /api/v1/users/1?extra_fields[]=asdfg
    #
    #   {
    #     "data": {
    #       ...
    #     },
    #     "warnings": [
    #       "The optional field 'asdfg' does not exist."
    #     ]
    #   }
    #
    # @see QuirkyApi.configure
    def warnings(params)
      # Ignore unless warn_invalid_fields is set.
      return unless QuirkyApi.warn_invalid_fields

      # Basic information about the request.
      params = params.symbolize_keys
      req_fields = [*params[:extra_fields]].map(&:to_sym)
      klass_fields = [*_optional_fields]

      good_fields = klass_fields & req_fields
      bad_fields = (req_fields - klass_fields)

      # Find any invalid fields and add a message.
      bad = bad_fields.reduce([]) do |w, f|
        w << "The '#{f}' field is not a valid optional field"
      end if good_fields.blank? || good_fields.length != req_fields.length

      # Return the warnings.
      bad
    end
  end

  attr_accessor :params, :options
  def initialize(object, options = {})
    # Ensure that we're passing around parameters and options.
    @params = options[:params] || {}
    @options = options

    # Give the class access to the options too.
    self.class._options = options

    @params.each do |param, val|
      sp = param.to_sym

      if val.is_a?(Array)
        @options[sp] ||= []
        @options[sp] << val
        @options[sp].flatten!
      else
        @options[sp] = val
      end
    end

    # If we have default associations, join them to the requested ones.
    if self.class._default_associations.present?
      (@options[:associations] ||= [])
        .concat(self.class._default_associations || [])
        .map!(&:to_sym)
        .uniq!
    end

    # Optional fields and associations from the class level.
    @optional = [*self.class._optional_fields]
    @associations = [*self.class._associations]

    super
  end

  # Ovewrwrites +ActiveModel::Serializer#serializable_hash# to allow inclusion
  # and exclusion of specific fields.
  #
  # @see ActiveModel::Serializer#serializable_hash
  def serializable_hash
    attrs = self.class._attributes.dup.keys

    # Inclusive fields.
    if @options[:only].present? || @options[:fields].present?
      (@options[:only] ||= []).concat(@options[:fields] ||= [])
      attrs = (attrs & @options[:only].map(&:to_sym))

      filter_attributes(attrs)
    # Exclusive fields.
    elsif @options[:exclude].present?
      attrs = (attrs - @options[:exclude].map(&:to_sym))

      filter_attributes(attrs)
    # All the fields.
    else
      attributes
    end
  end

  # Overrides +ActiveModel::Serializer#attributes+ to include associations
  # and optional fields, if requested.
  #
  # @see ActiveModel::Serializer#attributes
  def attributes
    data = super

    # Optional fields.
    optional = _optional
    if optional.present?
      optional.each do |field|
        data[field] = get_optional_field(field)
      end
    end

    # Associations.
    joins = _associations
    if joins.present?
      joins.each do |join|
        data[join] = get_association(join)
      end
    end

    # All the things.
    data
  end

  # @see QuirkySerializer.warnings
  def warnings(params)
    self.class.warnings(params)
  end

  private

  # Returns requested optional fields that are also found in the serializer.
  # @return [Array] An array of valid optional fields.  Invalid fielsd will
  #                 throw a warning.
  def _optional
    @optional & [*@options[:extra_fields]].map(&:to_sym)
  end

  # Returns requested associations.  This also validates the presence of
  # associations on the request, if configured.
  #
  # @see QuirkyApi.configuration
  #
  # @raises InvalidAssociation
  # @returns [Array] An array of valid associations.
  def _associations
    returned = @associations & [*@options[:associations]].map(&:to_sym)

    # Stop here unless we want to throw exceptions for bad associations.
    return returned unless QuirkyApi.validate_associations

    # Find invalid associations and throw an exception for them.
    if returned.blank? || returned.length != [*@options[:associations]].length
      ([*@options[:associations]].map(&:to_sym) - @associations).each do |assoc|
        fail InvalidAssociation,
             "The '#{assoc}' association does not exist."
      end
    end

    returned
  end

  # Gets information about a specific association.  Associations are links
  # between one serializer and another.
  #
  # You may request associations' fields, associations and optional fields
  # in the request, by specifying +KEY_fields+, +KEY_associations+ or
  # +KEY_extra_fields+, where +KEY+ is the name of the assocation
  # (like 'profile').
  #
  # This will determine if the data is an array or not, and parse it properly.
  #
  # @see associations
  def get_association(data)
    key = data.to_s
    if respond_to?(data)
      data = send(data)
    elsif object.respond_to?(data)
      data = object.send(data)
    else
      if QuirkyApi.validate_associations
        fail InvalidAssociation,
             "The '#{data}' association does not exist."
      else
        return
      end
    end

    sub_fields, sub_associations, sub_opts = sub_request_fields(key.to_s)

    sub_options = {}
    sub_options[:only] = sub_fields if sub_fields.present?
    sub_options[:associations] = sub_associations if sub_associations.present?
    sub_options[:extra_fields] = sub_opts if sub_opts.present?

    if data.is_a?(Array)
      QuirkyArraySerializer.new(data, sub_options).as_json(root: false)
    elsif data.respond_to?(:active_model_serializer) && data.try(:active_model_serializer).present?
      data.active_model_serializer.new(data, sub_options).as_json(root: false)
    else
      data.as_json(root: false)
    end
  end

  def get_optional_field(field)
    if respond_to?(field)
      return send(field).as_json
    elsif object.respond_to?(field)
      return object.send(field)
    end

    nil
  end

  # Filters attributes and returns their values.
  #
  # @param attrs [Array] All of the attributes we need values for.
  # @return [Hash] A hash of key / value pairs.
  def filter_attributes(attrs)
    attrs.each_with_object({}) do |name, inst|
      inst[name] = send(name)
    end
  end

  # Returns appropriate sub-fields, sub-associations and/or
  # sub-extra_fields for a particular association.
  #
  # @see get_association
  # @return [Array] an array of fields, associations and optional fields.
  def sub_request_fields(key)
    return unless @params[key + '_fields'].present? ||
                  @params[key + '_associations'].present? ||
                  @params[key + '_extra_fields'].present?

    sub_fields = [*@params[key + '_fields']]
    sub_associations = [*@params[key + '_associations']]
    sub_opt_fields = [*@params[key + '_extra_fields']]

    [sub_fields, sub_associations, sub_opt_fields]
  end
end
