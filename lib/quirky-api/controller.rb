# encoding: utf-8

module QuirkyApi
  require 'will_paginate'

  # The +QuirkyApi::Base+ class inherits from ActionController::Metal to offer
  # only the functionality that the API requires.  Using
  # +ActionController::Metal+ means that many standard rails methods
  # may be unavailable in the API.
  #
  # Extend from +QuirkyApi::Base+ to include API functionality.
  #
  # @example
  #  class Api::V1::InventionsController < QuirkyApi::Base
  #    # Intentionally left blank
  #  end
  class Base < ActionController::Metal
    # Core Rails functionality.
    include AbstractController::Rendering
    include AbstractController::Callbacks
    include ActionController::Rendering
    include ActionController::Renderers::All
    include ActionController::Helpers
    include ActionController::Rescue
    include ActionController::Caching
    include ActionController::StrongParameters
    include ActionController::Cookies

    # API functionality.
    include QuirkyApi::Rescue
    include QuirkyApi::Bouncer
    include QuirkyApi::Session
    include QuirkyApi::Mobile
    include QuirkyApi::Response
    include QuirkyApi::Can

    def self.inherited(base)
      # Include the configured QuirkyApi.auth_system module in the inherited class.
      base.send(:include, ::QuirkyApi.auth_system) if QuirkyApi.auth_system.is_a?(Module)

      # Include the base ApplicationHelper, if possible, in the API controller.
      base.send(:include, ::ApplicationHelper) if defined? ::ApplicationHelper

      # Include Rails routes helpers.
      base.send(:include, ::Rails.application.routes.url_helpers)
    end
  end
end
