# frozen_string_literal: true

module BetterTogether
  module Federation
    # Serves the federated content feed for authenticated platform connections.
    class ContentFeedController < ::BetterTogether::ApplicationController
      skip_before_action :store_user_location!
      skip_before_action :set_platform_invitation
      skip_before_action :check_platform_privacy
      skip_before_action :check_platform_setup

      def show
        return head :unauthorized unless connection

        auth_check = authorize_feed_access
        return auth_check if auth_check

        export = fetch_content_export
        render json: { seeds: export.seeds, next_cursor: export.next_cursor }
      end

      private

      def authorize_feed_access
        if access_token_record.present? && !access_token_record.includes_scope?('content.feed.read')
          return head :forbidden
        end

        auth_result = ::BetterTogether::FederationScopeAuthorizer.call(
          source_platform: connection.source_platform,
          target_platform: connection.target_platform,
          requested_scopes: ['content.feed.read']
        )
        head :forbidden unless auth_result.allowed?
      end

      def fetch_content_export
        ::BetterTogether::Content::FederatedContentExportService.call(
          connection:,
          cursor: params[:cursor],
          limit: params[:limit]
        )
      end

      def connection
        @connection ||= access_token_record&.platform_connection
      end

      def access_token_record
        @access_token_record ||= begin
          token = ::BetterTogether::FederationAccessToken.find_active_by_plaintext(bearer_token)

          if token.present? && token.platform_connection.source_platform == Current.platform
            token.touch_last_used!
            token
          end
        end
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
