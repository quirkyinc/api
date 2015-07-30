class ElementsAdapter < ApiAdapter
  def call
    return data unless data.is_a?(Hash)

    # +elements+ are top level keys in the JSON response, appearing at the
    # same level as the envelope for data.  You can specify as many elements
    # as you want, so long as they are a hash.
    if options[:elements].present? && options[:elements].is_a?(Hash)
      data.merge!(options[:elements])
    end

    data
  end
end
