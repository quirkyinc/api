# encoding: utf-8

module QuirkyApi
  # The Mobile module provides the functionality to test mobile requests and
  # provide specific information about them.
  module Mobile
    # Returns whether the request is being sent from the Quirky app.
    # @return [Bool]
    def ios_app?
      request.present? &&
      request.env.present? &&
      request.env['HTTP_USER_AGENT'].present? &&
      request.env['HTTP_USER_AGENT'].index('Quirky/').present?
    end

    # Returns the version of the iOS app, if applicable.
    def ios_header
      request.headers['X-App-Version'].gsub('iOS Platform-', '').to_s
    end

    # Determine if the request is NOT being sent by the iSO app.
    def not_ios
      request.headers['X-App-Version'].blank?
    end

    # iOS version checker.  Determines if the version of the iOS app in the
    # request matches your criteria.
    #
    # @param version [String] The version you want to condition against.
    # @param threshhold [Symbol] Determines how to match the version.
    #                            * :equals will return true if the app version
    #                              exactly matches the requested +version+.
    #                            * :minimum will return true if the app version
    #                              is greater than or equal to the requested
    #                              +version+.
    #                            * :maximum will return true if the app version
    #                              is less than or equal to the requested
    #                              +version+.
    #
    # @example
    #   ios_version('3.1.2', :equals)
    #
    # @return [Bool]
    def ios_version(version, threshhold = :equals)
      return true if request.blank? || not_ios

      case threshhold
      when :equals
        ios_header == version.to_s
      when :minimum
        ios_header >= version.to_s
      when :maximum
        ios_header <= version.to_s
      end
    end
  end
end
