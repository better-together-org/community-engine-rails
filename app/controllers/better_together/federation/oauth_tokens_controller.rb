# frozen_string_literal: true

module BetterTogether
  module Federation
    # OAuth 2.0 client_credentials token endpoint for machine-to-machine federation auth.
    # Inherits from Federation::ApiController (ActionController::API) so CSRF protection
    # is never included — requests are authenticated via client_id/client_secret only.
    class OauthTokensController < ::BetterTogether::Federation::ApiController # rubocop:disable Metrics/ClassLength
      def create # rubocop:disable Metrics/MethodLength
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

      def authorized_connection # rubocop:disable Metrics/AbcSize
        return if Current.platform.blank?

        candidate = ::BetterTogether::PlatformConnection.active.find_by(
          source_platform: Current.platform,
          oauth_client_id: params[:client_id].to_s
        )
        return if candidate.nil? || candidate.oauth_client_secret.blank? || params[:client_secret].blank?

        # Compare SHA256 digests to guarantee equal-length inputs to secure_compare,
        # preventing ArgumentError on length mismatch while preserving timing-safe comparison.
        candidate_digest = Digest::SHA256.hexdigest(candidate.oauth_client_secret)
        provided_digest  = Digest::SHA256.hexdigest(params[:client_secret].to_s)
        return unless ActiveSupport::SecurityUtils.secure_compare(candidate_digest, provided_digest)

        candidate
      end

      def render_oauth_error(error, status:, description: nil)
        payload = { error: }
        payload[:error_description] = description if description.present?
        render json: payload, status:
      end
    end
  end
end
