# frozen_string_literal: true

module BetterTogether
  module Federation
    class ContentFeedController < ::BetterTogether::ApplicationController
      skip_before_action :store_user_location!
      skip_before_action :set_platform_invitation
      skip_before_action :check_platform_privacy
      skip_before_action :check_platform_setup

      def show
        return head :unauthorized unless connection

        auth_result = ::BetterTogether::FederationScopeAuthorizer.call(
          source_platform: connection.source_platform,
          target_platform: connection.target_platform,
          requested_scopes: ['content.feed.read']
        )

        return head :forbidden unless auth_result.allowed?

        export = ::BetterTogether::Content::FederatedContentExportService.call(
          connection:,
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
        @connection ||= resolve_connection_from_bearer_token
      end

      def resolve_connection_from_bearer_token
        token = bearer_token
        return if token.blank? || Current.platform.blank?

        ::BetterTogether::PlatformConnection.active
                                           .where(source_platform: Current.platform)
                                           .find do |candidate|
          candidate.federation_access_token.present? &&
            ActiveSupport::SecurityUtils.secure_compare(candidate.federation_access_token, token)
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
