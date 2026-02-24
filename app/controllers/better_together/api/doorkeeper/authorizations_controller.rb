# frozen_string_literal: true

module BetterTogether
  module Api
    module Doorkeeper
      # Wrapper around Doorkeeper's authorization endpoint for the engine API namespace.
      #
      # This enables the `authorization_code` grant flow at `/api/oauth/authorize`.
      class AuthorizationsController < ::Doorkeeper::AuthorizationsController
      end
    end
  end
end
