# encoding: utf-8

module QuirkyApi
  # The Bouncer module ensures that the API request is valid.  It also removes
  # before_filters that would potentially interfere with the API and sets
  # generic before_filters to be shared across all API's.
  module Bouncer
    def self.included(base)
      if base.respond_to?(:skip_before_filter) &&
         base.respond_to?(:before_filter)

        # error_check allows mobile to send fake error codes.
        base.send :before_filter, :raise_error_check

        # We don't need verify_authenticity_token in the API -- it should be
        # validated in other ways.
        base.send :skip_before_filter, :verify_authenticity_token
      end
    end

    # Raises a fake error if requested.  Send +params[:forced_error]+ with a
    # valid error code to be returned in the response.
    def raise_error_check
      return if Rails.env.production? || params[:forced_error].blank?
      error_response('Returning forced error.')
    end
  end
end
