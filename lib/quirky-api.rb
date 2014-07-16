# encoding: utf-8

# Core QuirkyApi modules
require 'quirky-api/configurable'
require 'quirky-api/rescue'
require 'quirky-api/bouncer'
require 'quirky-api/session'
require 'quirky-api/mobile'
require 'quirky-api/response'
require 'quirky-api/controller'

# Serializers
require 'quirky-api/serializers/quirky_serializer'
require 'quirky-api/serializers/quirky_array_serializer'

# The QuirkyApi module provides API functionality across Quirky apps.  With
# the +quirky-api+ gem, your application is given access to authentication,
# mobile and response methods.
#
# Read the README for more information about how the +quirky-api+ gem works.
module QuirkyApi
end
