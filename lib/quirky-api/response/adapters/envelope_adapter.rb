class EnvelopeAdapter < ApiAdapter
  def call
    # Envelope the data, if applicable.  In the event of a JSONP response,
    # the data will always be enveloped.
    envelope(data)
  end

  private

  # Envelopes data based on +QuirkyApi.envelope+.
  #
  # @param data [Object] Any type of object.
  #
  # @return [Hash] The enveloped data, if applicable.
  def envelope(data)
    return data if options[:envelope].blank?
    { options[:envelope].to_s => data }
  end
end
