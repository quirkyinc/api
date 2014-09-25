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
    require 'new_relic/agent/instrumentation/rack' if defined? ::NewRelic

    # Core Rails functionality.
    include AbstractController::Rendering
    include AbstractController::Callbacks
    include ActionController::Rendering
    include ActionController::Renderers::All
    include ActionController::Helpers
    include ActionController::Rescue
    include ActionController::Caching
    include ActionController::StrongParameters if defined? ActionController::StrongParameters
    include ActionController::Cookies
    include ActionController::Flash
    include ActionController::Head
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include ActionController::ConditionalGet

    # API functionality.
    include QuirkyApi::Session
    include QuirkyApi::Rescue
    include QuirkyApi::Bouncer
    include QuirkyApi::Mobile
    include QuirkyApi::Response
    include QuirkyApi::Can
    include QuirkyApi::Global

    extend Apipie::DSL::Concern if defined? Apipie

    def self.inherited(base)
      # Include the configured QuirkyApi.auth_system module in the inherited class.
      base.send(:include, ::QuirkyApi.auth_system) if QuirkyApi.auth_system.is_a?(Module)
      base.send(:include, QuirkyApi::Bouncer)

      base.send(:include, ActionController::Instrumentation)

      # Ensure that we always trace controller actions in Rails < 4.0.  Rails 4
      # uses ActionController::Instrumentation to automatically watch
      # every request.
      if defined?(Rails) && Rails::VERSION::STRING.to_f <= 4.0
        base.send(:include, ::NewRelic::Agent::Instrumentation::ControllerInstrumentation)
        base.send(:before_filter, lambda { self.class.add_transaction_tracer(params[:action].to_sym) })
      end

      begin
        # Include the base ApplicationHelper, if possible, in the API controller.
        base.send(:include, ::ApplicationHelper)
      rescue NameError
        # No ApplicationHelper.  No problem.
      end

      # Include Rails routes helpers.
      base.send(:include, ::Rails.application.routes.url_helpers)
    end
  end
end
