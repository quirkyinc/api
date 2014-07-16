# encoding: utf-8

module QuirkyApi
  # The Rescue module rescues certain exceptions and returns their responses
  # in a JSON response.  If +QuirkyApi.show_exceptions+ is specified, all
  # exceptions will raise as normal.
  module Rescue
    def self.included(base)
      if base.respond_to?(:rescue_from) && !QuirkyApi.show_exceptions
        base.send :rescue_from, '::CanCan::AccessDenied', with: :unauthorized           # 401 Unauthorized
        base.send :rescue_from, '::InvalidAssociation', with: :error                    # 400 Bad Request
        base.send :rescue_from, '::ActiveRecord::RecordInvalid', with: :record_invalid  # 400 Bad Request
        base.send :rescue_from, '::ActiveRecord::RecordNotFound', with: :not_found      # 404 Not Found
        base.send :rescue_from, '::ActiveRecord::RecordNotUnique', with: :not_unique    # 409 Conflict
      end
    end
  end
end
