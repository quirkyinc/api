# encoding: utf-8

module QuirkyApi
  # The Bouncer module ensures that the API request is valid.  It also removes
  # before_filters that would potentially interfere with the API and sets
  # generic before_filters to be shared across all API's.
  module Bouncer
    def self.included(base)
      if base.respond_to?(:skip_before_filter) &&
         base.respond_to?(:before_filter)

        # Skip all before_filters.  The API is a separate entity.
        base.send :skip_filter, *_process_action_callbacks.map(&:filter)

        # error_check allows mobile to send fake error codes.
        base.send :before_filter, :raise_error_check

        # Double checks the API token.
        base.send :before_filter, :valid_api_credentials?
      end
    end

    # Ensures that API credentials are valid.  This may disappear one day.
    def valid_api_credentials?
      # If you're logged in, or the request is coming from web, there are other
      # securities in place.
      return true if logged_in? ||
                     request.headers['X-App-Version'].blank? ||
                     request.method == :GET

      # API tokens must be passed in the Authorization header.
      authenticate_or_request_with_http_token do |token|
        ApiKey.valid_token?(token)
      end

      false
    end

    # Raises a fake error if requested.  Send +params[:forced_error]+ with a
    # valid error code to be returned in the response.
    def raise_error_check
      return if Rails.env.production? || params[:forced_error].blank?
      error_response('Returning forced error.')
    end
  end
end
