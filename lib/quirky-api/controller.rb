# encoding: utf-8

require 'rails-api/action_controller/api'

module QuirkyApi
  # The base class provides the standard functionality that every API requires.
  # Inherit your contorller from QuirkyApi::Base to include the functionality.
  #
  # @example
  #  class Api::V1::InventionsController < QuirkyApi::Base
  #    # Intentionally left blank
  #  end
  class Base < ActionController::API
    require 'active_model_serializers'

    include QuirkyApi::Rescue
    include QuirkyApi::Bouncer
    include QuirkyApi::Session
    include QuirkyApi::Mobile
    include QuirkyApi::Response
    include QuirkyApi::Can
  end
end
