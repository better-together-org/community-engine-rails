# frozen_string_literal: true

module BetterTogether
  module Federation
    # Base controller for machine-to-machine federation endpoints (e.g. OAuth token issuance).
    # Inherits from BetterTogether::ApplicationController but scopes CSRF protection to
    # browser (non-JSON) requests only — matching the pattern used by Api::ApplicationController.
    # These endpoints are authenticated via OAuth client_id/client_secret, not session cookies.
    class ApiController < ::BetterTogether::ApplicationController
      # M2M federation endpoints authenticate via OAuth client_id/client_secret.
      # CSRF protection is intentionally scoped to non-JSON requests only — matching the
      # pattern in Api::ApplicationController. JSON requests carry credentials in the
      # request body, not browser cookies, so CSRF is not a threat vector here.
      # codeql[rb/csrf-protection-disabled]
      protect_from_forgery with: :exception, unless: -> { request.format.json? }

      skip_before_action :store_user_location!
      skip_before_action :set_platform_invitation
      skip_before_action :check_platform_privacy
      skip_before_action :check_platform_setup

      private

      # Shared bearer-token helpers for subcontrollers that use FederationAccessToken auth.
      # Subcontrollers override `connection` to add per-endpoint platform direction checks.

      def access_token
        @access_token ||= ::BetterTogether::FederationAccessToken.find_active_by_plaintext(bearer_token)
      end

      def bearer_token
        authorization = request.authorization.to_s
        scheme, token = authorization.split(' ', 2)
        return unless scheme&.casecmp('Bearer')&.zero?

        token.to_s
      end
    end
  end
end
