# encoding: utf-8

# Exception for associations that are not valid.
class InvalidAssociation < ::Exception ; end

# Dependencies
require 'active_model_serializers'

# QuirkyAPI methods that are available to the entire app.
require 'quirky-api/global_methods'
include QuirkyApi::Global


require 'quirky-api/railtie'

# The QuirkyApi module provides API functionality across Quirky apps.  With
# the +quirky-api+ gem, your application is given access to authentication,
# mobile and response methods.
#
# Read the README for more information about how the +quirky-api+ gem works.
module QuirkyApi
  # Core QuirkyApi modules
  require 'quirky-api/configurable'
  require 'quirky-api/rescue'
  require 'quirky-api/bouncer'
  require 'quirky-api/auth'
  require 'quirky-api/response'
  require 'quirky-api/can'
  require 'quirky-api/controller'

  # Serializers
  require 'quirky-api/serializers/quirky_serializer'
  require 'quirky-api/serializers/quirky_array_serializer'
  require 'quirky-api/paginated_patch'
end
