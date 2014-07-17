# encoding: utf-8

module QuirkyApi
  require 'will_paginate'

  # The base class provides the standard functionality that every API requires.
  # Inherit your contorller from QuirkyApi::Base to include the functionality.
  #
  # @example
  #  class Api::V1::InventionsController < QuirkyApi::Base
  #    # Intentionally left blank
  #  end
  class Base < ActionController::API
    include QuirkyApi::Rescue
    include QuirkyApi::Bouncer
    include QuirkyApi::Session
    include QuirkyApi::Mobile
    include QuirkyApi::Response
    include QuirkyApi::Can

    def self.inherited(base)
      base.send(:include, ::QuirkyAuth::Authorization)
    end
  end
end
