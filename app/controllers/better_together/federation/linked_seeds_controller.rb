# frozen_string_literal: true

module BetterTogether
  module Federation
    # Serves linked seed payloads for federated platform synchronization.
    class LinkedSeedsController < ::BetterTogether::ApplicationController
      skip_before_action :store_user_location!
      skip_before_action :set_platform_invitation
      skip_before_action :check_platform_privacy
      skip_before_action :check_platform_setup

      def index
        return head :unauthorized unless connection
        return head :forbidden unless linked_content_token_authorized?

        export = ::BetterTogether::Seeds::LinkedSeedExportService.call(
          connection:,
          recipient_identifier: params[:recipient_identifier],
          cursor: params[:cursor],
          limit: params[:limit]
        )

        render json: {
          seeds: export.seeds,
          next_cursor: export.next_cursor
        }
      end

      private

      def connection
        @connection ||= begin
          token = ::BetterTogether::FederationAccessToken.find_active_by_plaintext(bearer_token)
          if token.present? && token.platform_connection.source_platform == Current.platform
            token.touch_last_used!
            token.platform_connection
          end
        end
      end

      def linked_content_token_authorized?
        token = ::BetterTogether::FederationAccessToken.find_active_by_plaintext(bearer_token)
        return false unless token&.includes_scope?('linked_content.read')

        auth_result = ::BetterTogether::FederationScopeAuthorizer.call(
          source_platform: connection.source_platform,
          target_platform: connection.target_platform,
          requested_scopes: ['linked_content.read']
        )
        auth_result.allowed?
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
