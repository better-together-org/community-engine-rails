# frozen_string_literal: true

module BetterTogether
  module Federation
    # Base controller for machine-to-machine (non-browser) federation endpoints.
    # Inherits from ActionController::API so CSRF protection is never included —
    # these endpoints authenticate via OAuth client credentials, not browser sessions.
    class ApiController < ActionController::API
      before_action :set_current_platform_context
      after_action :reset_current_platform_context

      private

      def set_current_platform_context
        Current.platform_domain = ::BetterTogether::PlatformDomain.resolve(request.host)
        Current.platform = Current.platform_domain&.platform || ::BetterTogether::Platform.find_by(host: true)
      end

      def reset_current_platform_context
        Current.reset
      end
    end
  end
end
