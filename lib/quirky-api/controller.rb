module QuirkyApi
  require 'rails-api/action_controller/api'
  class Base < ActionController::API
    require 'active_model_serializers'

    include QuirkyApi::Rescue
    include QuirkyApi::Bouncer
    include QuirkyApi::Session
    include QuirkyApi::Mobile
    include QuirkyApi::Response
  end
end
