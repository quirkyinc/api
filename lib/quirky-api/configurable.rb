# encoding: utf-8

# Allows configuration for the QuirkyApi module.
module QuirkyApi
  class << self
    attr_accessor :validate_associations, :warn_invalid_fields, :auth_system,
                  :show_exceptions, :stub_requests
    def configure
      yield(self)
    end
  end
end
