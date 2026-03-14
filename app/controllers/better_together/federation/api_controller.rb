# frozen_string_literal: true

module BetterTogether
  module Federation
    # Base controller for machine-to-machine federation endpoints (e.g. OAuth token issuance).
    # Inherits from BetterTogether::ApplicationController but scopes CSRF protection to
    # browser (non-JSON) requests only — matching the pattern used by Api::ApplicationController.
    # These endpoints are authenticated via OAuth client_id/client_secret, not session cookies.
    class ApiController < ::BetterTogether::ApplicationController
      protect_from_forgery with: :exception, unless: -> { request.format.json? }

      skip_before_action :store_user_location!
      skip_before_action :set_platform_invitation
      skip_before_action :check_platform_privacy
      skip_before_action :check_platform_setup
    end
  end
end
