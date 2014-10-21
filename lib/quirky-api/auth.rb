# encoding: utf-8

module QuirkyApi
  # The Session module provides authentication methods to the API.
  module Auth
    def self.included(base)
      base.send(:include, QuirkyApi.auth_system) if QuirkyApi.auth_system.is_a?(Module)
    end
  end
end
