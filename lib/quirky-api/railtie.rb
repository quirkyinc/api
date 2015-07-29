module QuirkyApi
  class Railtie < Rails::Railtie
    initializer 'quirky_api.insert_middleware' do |app|
      # Ensure that GZIP is used at the very least for the API.
      app.config.middleware.use Rack::Deflater
    end

    initializer 'quirky_api' do |app|
      ActiveSupport.on_load(:active_record) do
        ::ActiveRecord::Base.send :include, QuirkyApi::Paginate::ActiveRecordExtension
      end
    end
  end
end
