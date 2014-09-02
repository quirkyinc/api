# encoding: utf-8


class InvalidField < StandardError ; end

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
#   class UserSerializer < QuirkySerializer
#     attributes :id, :name
#     optional :email
#     associations :avatar
#   end
#
class QuirkySerializer < ::ActiveModel::Serializer
  class << self
    attr_accessor :_optional_fields, :_associations, :_default_associations,
                  :_validations, :_options, :_cacheable_fields, :_cache

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
    #   class UserSerializer < QuirkySerializer
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
    #   class UserSerializer < QuirkySerializer
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
    #   class UserSerializer < QuirkySerializer
    #     associations :profile, :avatar
    #     default_associations :profile
    #   end
    #
    # @see associations
    def default_associations(*default_associations)
      Rails.logger.warn "DEPRECATION WARNING: 'default_associations' is deprecated and will be removed soon.  Ask for your associations on a per-endpoint basis."
      self._default_associations = default_associations
    end

    # This will ensure that content is secure by validating the passed block,
    # and only showing an attribute's content if the block returns +true+.  If
    # the block does not return +true+, this attribute's value will be +null+.
    #
    # @param attribute [Symbol] The attribute to run permission checks on.
    # @param validation [Block] A block that will be run to verify that the
    #                           viewing party has permission to see the
    #                           attribute.
    #
    # @example
    #   class UserSerializer < QuirkySerializer
    #     attributes :id, :name, :email
    #     verify_permissions :email, -> { @current_user.can? :update, object rescue false }
    #   end
    #
    #   class UserSerializer < QuirkySerializer
    #     attributes :id, :name, :email
    #     verify_permissions :email do
    #       @current_user.can? :update, object rescue false
    #     end
    #   end
    #
    # @see validates?
    def verify_permissions(attribute, validation = nil, &block)
      self._validations ||= {}
      self._validations[attribute] = (validation.present? ? validation : block)
    end

    def caches(*attrs)
      fields = []

      if attrs.include? :all
        fields.concat [*self._attributes.keys].map(&:to_sym) +
                      [*self._optional_fields].map(&:to_sym) +
                      [*self._associations].map(&:to_sym)
      end

      if attrs.include? :associations
        fields.concat self._associations
      end

      if attrs.include? :optional_fields
        fields.concat self._optional_fields
      end

      if attrs.include? :fields
        fields.concat self._attributes
      end

      self._cacheable_fields = fields
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

  attr_accessor :params, :options, :current_user
  def initialize(object, options = {})
    # Ensure that we're passing around parameters and options.
    @params = options[:params] || {}
    @options = options
    @current_user = options[:current_user]

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

    if @options[:associations].is_a? String
      @options[:associations] = @options[:associations].split(',')
    end

    if @options[:fields].is_a? String
      @options[:fields] = @options[:fields].split(',')
    end

    if @options[:extra_fields].is_a? String
      @options[:extra_fields] = @options[:extra_fields].split(',')
    end

    # If we have default associations, join them to the requested ones.
    if self.class._default_associations.present?
      @options[:associations] ||= []
      @options[:associations].concat(self.class._default_associations || []) unless @options[:only].present?

      @options[:associations]
        .map!(&:to_sym)
        .uniq!
    end

    # Optional fields and associations from the class level.
    @optional = [*self.class._optional_fields]
    @associations = [*self.class._associations]
    @validations = self.class._validations

    if object.respond_to?(:id) && object.respond_to?(:updated_at)
      self.class._cache ||= {}
      self.class._cache["#{object.id}.#{object.updated_at.to_i}"] ||= {}
    end

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
    # Exclusive fields.
    elsif @options[:exclude].present?
      attrs = (attrs - @options[:exclude].map(&:to_sym))
    end

    filter_attributes(attrs)
  end

  # @see QuirkySerializer.warnings
  def warnings(params)
    self.class.warnings(params)
  end

  # Returns the correct serializer for an object, or collection of objects
  def self.get_serializer(object)
    if object.respond_to?(:active_model_serializer) &&
       object.try(:active_model_serializer).present?

     serializer = object.active_model_serializer
     if serializer <= ActiveModel::ArraySerializer
       serializer = QuirkyArraySerializer
     end

     serializer
   else
     nil
   end
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

    begin
      data = get_field(data)
    rescue InvalidField => e
      if QuirkyApi.validate_associations
        raise InvalidAssociation,
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
    sub_options[:current_user] = @current_user

    if data.is_a?(Array)
      QuirkyArraySerializer.new(data, sub_options).as_json(root: false)
    elsif data.respond_to?(:active_model_serializer) && data.try(:active_model_serializer).present?
      data.active_model_serializer.new(data, sub_options).as_json(root: false)
    else
      data.as_json(root: false)
    end
  end

  def _cached_field(field)
    self.class._cache["#{object.id}.#{object.updated_at.to_i}"][field]
  end

  def _set_cached_field(field, value)
    self.class._cache["#{object.id}.#{object.updated_at.to_i}"][field] = Rails.cache.fetch([object, field]) { value }
  end

  def _cached?(field)
    self.class._cacheable_fields.present? && self.class._cacheable_fields.include?(field.to_sym)
  end

  def _in_cache?(field)
    return false if self.class._cache.blank?
    self.class._cache["#{object.id}.#{object.updated_at.to_i}"][field].present?
  end

  # Attempts to get the value of a certain field by first checking the
  # serializer, then the object.  If neither the serializer nor the
  # object respond to the method, raises an +InvalidField+ exception.
  #
  # @param field [String|Symbol] The attribute to get the value for.
  #
  # @return [Mixed] Either the value of the attribute, or +InvalidField+ if
  #                 neither the serializer nor the object responds to the
  #                 assumed method.
  def get_field(field)
    if _cached?(field)
      return _cached_field(field) if _in_cache?(field)
    end

    response = if respond_to?(field)
                 send(field) if validates? field
               elsif object.respond_to?(field)
                 object.send(field) if validates? field
               else
                 fail InvalidField, "#{field} could not be found"
               end

    if _cached?(field)
      _set_cached_field(field, response)
    else
      response
    end
  end

  # Confirms that a field passes validations.
  #
  # @param field [String|Symbol] The field to check validations on.
  # @return [Bool] True if the viewer can see, false if not.
  def validates?(field)
    return true if @validations.blank?

    # Check if there is a validation at all for this field.
    validation = @validations[field.to_sym]
    return true if validation.blank?

    # Call block
    instance_exec(&validation) === true
  end

  # Filters attributes and returns their values.
  #
  # @param attrs [Array] All of the attributes we need values for.
  # @return [Hash] A hash of key / value pairs.
  def filter_attributes(attrs)
    attributes = attrs.each_with_object({}) do |name, inst|
      inst[name] = get_field(name) rescue nil
    end

    optional_fields = _optional
    if optional_fields.present?
      optional_fields.each do |field|
        attributes[field] = get_field(field) rescue nil
      end
    end

    associated_fields = _associations
    if associated_fields.present?
      associated_fields.each do |assoc|
        attributes[assoc] = get_association(assoc)
      end
    end

    attributes
  end

  # Returns appropriate sub-fields, sub-associations and/or
  # sub-extra_fields for a particular association.
  #
  # @see get_association
  # @return [Array] an array of fields, associations and optional fields.
  def sub_request_fields(key)
    return unless @options[:"#{key}_fields"].present? ||
                  @options[:"#{key}_associations"].present? ||
                  @options[:"#{key}_extra_fields"].present?

    sub_fields = [*@options[:"#{key}_fields"]]
    sub_associations = [*@options[:"#{key}_associations"]]
    sub_opt_fields = [*@options[:"#{key}_extra_fields"]]

    [sub_fields, sub_associations, sub_opt_fields]
  end
end
