class WarningsAdapter < ApiAdapter
  def call
    return data unless data.is_a?(Hash)
    return data unless QuirkyApi.warn_invalid_fields
    return data unless options[:serialized_data].present?

    warnings = options[:serialized_data].warnings(options[:params])
    data[:warnings] = warnings if warnings.present?

    data
  end
end
