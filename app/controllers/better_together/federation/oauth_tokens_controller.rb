# frozen_string_literal: true

module BetterTogether
  module Federation
    class OauthTokensController < ::BetterTogether::ApplicationController
      skip_before_action :verify_authenticity_token
      skip_before_action :store_user_location!
      skip_before_action :set_platform_invitation
      skip_before_action :check_platform_privacy
      skip_before_action :check_platform_setup

      def create
        return render_oauth_error('unsupported_grant_type', status: :bad_request) unless grant_type == 'client_credentials'

        connection = authorized_connection
        return render_oauth_error('invalid_client', status: :unauthorized) unless connection

        issued = ::BetterTogether::FederationAccessTokenIssuer.call(
          connection:,
          requested_scopes: requested_scopes
        )

        render json: {
          access_token: issued.access_token,
          token_type: 'Bearer',
          expires_in: issued.expires_in,
          scope: issued.scope
        }
      rescue ArgumentError => e
        render_oauth_error('invalid_scope', description: e.message, status: :forbidden)
      end

      private

      def grant_type
        params[:grant_type].to_s
      end

      def requested_scopes
        params[:scope].to_s
      end

      def authorized_connection
        return if Current.platform.blank?

        candidate = ::BetterTogether::PlatformConnection.active.find_by(
          source_platform: Current.platform,
          oauth_client_id: params[:client_id].to_s
        )
        return if candidate.nil? || candidate.oauth_client_secret.blank? || params[:client_secret].blank?
        return unless ActiveSupport::SecurityUtils.secure_compare(candidate.oauth_client_secret, params[:client_secret].to_s)

        candidate
      end

      def render_oauth_error(error, description: nil, status:)
        payload = { error: }
        payload[:error_description] = description if description.present?
        render json: payload, status:
      end
    end
  end
end
