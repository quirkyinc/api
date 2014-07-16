module QuirkyApi
  module Bouncer
    def self.included(base)
      if base.respond_to?(:skip_before_filter) && base.respond_to?(:before_filter)
        # For QC
        base.send :skip_before_filter, :check_tnc
        base.send :skip_before_filter, :require_unquarantined_user
        base.send :skip_before_filter, :check_active_chat
        base.send :skip_before_filter, :check_blackout
        base.send :skip_before_filter, :check_shouts
        base.send :skip_before_filter, :serialize_global_backbone_data

        # We use API Keys and OAuth to confirm valid requests.
        base.send :skip_before_filter, :verify_authenticity_token

        # error_check allows mobile to send fake error codes.
        base.send :before_filter, :raise_error_check

        # Double checks the API token.
        base.send :before_filter, :valid_api_credentials?, unless: -> { request.method == :GET }
      end
    end

    # Ensures that API credentials are valid.  This may disappear one day.
    def valid_api_credentials?
      # If you're logged in, or the request is coming from web, there are other
      # securities in place.
      return true if logged_in? || request.headers['X-App-Version'].blank?

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

      error_response(
         I18n.t('api.generic.response.forced'),
         params[:forced_error]
       )
    end
  end
end
