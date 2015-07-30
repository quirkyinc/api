class PrettyPrintAdapter < ApiAdapter
  def call
    return data unless QuirkyApi.pretty_print?

    # If configured, we pretty JSON responses.  This is the default response.
    JSON.pretty_generate(data)
  end
end
