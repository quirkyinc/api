module QuirkyApi
  class Railtie < Rails::Railtie
    initializer 'quirky_api.insert_middleware' do |app|
      # Ensure that GZIP is used at the very least for the API.
      app.config.middleware.use Rack::Deflater
      app.config.middleware.use QuirkyApi::RateLimiting if QuirkyApi.rate_limit?
    end
  end

  class RateLimiting
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      binding.pry

      @app.cal(env)
    end
  end
end
