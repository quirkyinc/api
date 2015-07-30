class JsonpAdapter < ApiAdapter
  def call
    # Because JSONP responses wrap the response within a function, we append
    # extra meta information to the response so we get essentially the same
    # results as if we made a request with AJAX or something.  JSONP
    # responses *must* be wrapped in an envelope so that the meta information
    # can be passed forward.
    #
    # Using JSONP means that the response will always return 200 (OK), and
    # you should use the meta 'status' attribute to retrieve the actual
    # status code.
    callback = (options[:params].presence && options[:params][:callback].presence) || options[:callback]
    if QuirkyApi.jsonp? && callback.present?
      # JSONP responses must be wrapped in an envelope so there can be meta information.
      options[:envelope] = 'data' if options[:envelope].blank?
      (options[:elements] ||= {}).merge!(meta: { status: options[:status].presence || 200 })
    end

    data
  end

  def finalize(renderable)
    # As described above, if this is a JSONP response, we respond 200 (OK)
    # and specify the callback to +render+.  Otherwise, we use the default
    # status code.
    callback = (options[:params].presence && options[:params][:callback].presence) || options[:callback]
    if QuirkyApi.jsonp? && callback.present?
      renderable[:callback] = callback
      renderable[:status] = 200
    else
      renderable[:status] = options[:status] if options[:status].present?
    end

    renderable
  end
end
