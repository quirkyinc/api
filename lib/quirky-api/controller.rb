# encoding: utf-8

module QuirkyApi
  require 'will_paginate'

  # The base class provides the standard functionality that every API requires.
  # Inherit your contorller from QuirkyApi::Base to include the functionality.
  #
  # @example
  #  class Api::V1::InventionsController < QuirkyApi::Base
  #    # Intentionally left blank
  #  end
  class Base < ActionController::Base
    include ActionController::Cookies

    include QuirkyApi::Rescue
    include QuirkyApi::Bouncer
    include QuirkyApi::Session
    include QuirkyApi::Mobile
    include QuirkyApi::Response
    include QuirkyApi::Can

    def self.inherited(base)
      base.send(:include, ::QuirkyApi.auth_system) if QuirkyApi.auth_system.is_a?(Module)
      base.send(:include, ::ApplicationHelper)
      base.send(:include, ::Rails.application.routes.url_helpers)
    end
  end
end
