class PaginatedMetaAdapter < ApiAdapter
  def call
    return data unless data.is_a?(Hash)

    if options[:paginated_meta].present? && options[:paginated_meta].is_a?(Hash)
      # Paginated meta is information returned from our custom implementation
      # of pagination.
      data.merge!(options[:paginated_meta]) if options[:paginated_meta].present?
    end

    data
  end
end
