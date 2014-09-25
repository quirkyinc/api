module QuirkyApi
  # This railtie ensures that the _quirky_auth cookie is present in all
  # QuirkyQc requests, by prepending it as a header.
  class Railtie < Rails::Railtie
    initializer 'quirky_qc.insert_middleware' do |app|
      app.config.middleware.use 'QuirkyApi::CookieMiddleware'
      app.config.plugins = [:all, :newrelic_rpm]
    end

    initializer 'quirky_api.newrelic' do |app|
      ::NewRelic::Control.instance.init_plugin(config: app.config) if defined? ::NewRelic
    end
  end

  # The CookieMiddleware middleware checks for the presence of the _quirky_auth
  # cookie and, if applicable, prepends it to the QuirkyQc headers.
  class CookieMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      headers = {}

      if request.cookie_jar.key?(:_quirky_auth)
        headers['Quirky-Cookie'] = request.cookie_jar[:_quirky_auth]
      end

      QuirkyApi::Client.prepend_headers(headers)

      @app.call(env)
    end
  end
end
