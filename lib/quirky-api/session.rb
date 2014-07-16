# encoding: utf-8

module QuirkyApi
  # The Session module provides authentication methods to the API.
  module Session
    def self.included(base)
      base.send(:include, QuirkyApi.auth_system) if QuirkyApi.auth_system
    end

    # Stub for logged_in? method, to be obtained by the parent app.
    def logged_in?
      Object.respond_to?(:current_user) ? current_user.present? : false
    end

    # Returns a a 401 unauthorized response.
    def requires_login
      respond_unauthorized
    end
  end
end
