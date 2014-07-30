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
  class Base < ActionController::Metal
    include AbstractController::Rendering
    include ActionController::Rendering
    include ActionController::Renderers::All
    include ActionController::MimeResponds
    include ActionController::ImplicitRender
    include AbstractController::Callbacks
    include ActionController::Helpers
    include ActionController::Rescue
    include ActiveSupport::Rescuable
    # include ActionController::Redirecting
    # include ActionController::Renderers::All
    # include ActionController::ConditionalGet
    # include ActionController::MimeResponds
    # include ActionController::RequestForgeryProtection
    # include ActionController::ForceSSL
    # include AbstractController::Callbacks
    # include ActionController::Instrumentation
    # include ActionController::ParamsWrapper
    # include ActionController::Rendering
    # include AbstractController::Rendering

    include ActionController::Cookies

    include QuirkyApi::Rescue
    include QuirkyApi::Bouncer
    include QuirkyApi::Session
    include QuirkyApi::Mobile
    include QuirkyApi::Response
    include QuirkyApi::Can

    def self.inherited(base)
      base.send(:include, ::QuirkyApi.auth_system) if QuirkyApi.auth_system.is_a?(Module)
      base.send(:include, ::ApplicationHelper) if defined? ::ApplicationHelper
      base.send(:include, ::Rails.application.routes.url_helpers)
    end
  end
end
