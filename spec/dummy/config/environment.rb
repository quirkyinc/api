# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

# Set default host
Rails.application.routes.default_url_options[:host] = 'test.host'
