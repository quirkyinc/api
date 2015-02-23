# encoding: utf-8

# The +QuirkyArraySerializer+ handles serialization of arrays of data.
# QuirkyArraySerializer will find the serializer for each element in the array,
# run it on that element, and return the array with serialized data.
#
# @example
#   QuirkyArraySerializer.new(@items.all).as_json(root: false)
#   #=> [{ "id": 1, "name": "one" }, { "id": 2, "name": "two" }, ...]
class QuirkyArraySerializer < ::ActiveModel::ArraySerializer
  attr_accessor :params, :serializer_options
  def initialize(object, options = {})
    super(object, options)

    @serializer_options = options
    @params = options[:params] || {}
    @request = options[:request] || {}
    # More quirky-specific configuration can go here.
  end

  def warnings(params)
    QuirkySerializer.warnings(params)
  end

  class << self
    def get_serializer(key)
      if key.class <= Paperclip::Attachment
        PaperclipAttachmentSerializer
      elsif key.class <= ShopAttachment
        ShopAttachmentSerializer
      elsif key.class <= Attachment
        AttachmentSerializer
      # elsif key.class <= Money
      #   MoneySerializer
      else
        unless key.class <= QuirkySerializer || [true, false].include?(key) || key.class <= Money
          key && key.active_model_serializer
        else
          nil
        end
      end
    end

    # Figures out the required serializer for all data passed to it, serializes it, and returns all data again.
    # If any object in the dataset does not have a serialier, calls +as_json+ on it.
    #
    # ==== Options
    # * <tt>objects</tt> - Data that you would like to be serialized.
    #
    # ==== Examples
    #   QuirkyArraySerializer.serialize(Rating.last)
    #   # => {"created_at"=>Wed, 15 Jan 2014 16:16:32 EST -05:00, "criterion_id"=>nil, "deleted_at"=>nil, "id"=>2, "rateable_id"=>306, "rateable_type"=>"Comment", "updated_at"=>Wed, 15 Jan 2014 16:16:32 EST -05:00, "user_id"=>354056, "value"=>3}
    def serialize(objects, options={})
      serializable = []
      objs = [*objects]
      if objs.length > 0
        objs.each do |object|
          if object.class.name.present?
            unless object.class.name =~ /[A-Z]{1}[a-z]+Serializer/
              serializer = get_serializer(object) rescue false
              options[:root] = false
              unless serializer.blank? || serializer == false
                instance = serializer.new(object, options)
                serializable << (options[:convert] ? instance.as_json : instance)
              end
            else
              serializable << (options[:convert] ? object.as_json : object)
            end
          else
            serializable << (options[:convert] ? object.as_json : object)
          end
        end
      end

      [*serializable]
    end
  end
end
