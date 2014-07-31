# encoding: utf-8

module QuirkyApi
  # The Session module provides authentication methods to the API.
  module Session
    def self.included(base)
      base.send(:include, QuirkyApi.auth_system) if QuirkyApi.auth_system
    end

    # Stub for logged_in? method, to be obtained by the parent app.
    def logged_in?
      defined? current_user && current_user.present?
    end

    # Returns a a 401 unauthorized response.
    def requires_login
      respond_unauthorized unless logged_in?
    end
    alias_method :require_login, :requires_login
    alias_method :login_required, :requires_login

    def requires_admin
      respond_forbidden unless current_user && current_user.is_admin?
    end
    alias_method :require_admin, :requires_admin
    alias_method :admin_required, :requires_admin
  end
end
