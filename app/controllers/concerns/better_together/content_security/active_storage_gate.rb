# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Controller concern that gates ActiveStorage blob responses behind content-security scan results.
    module ActiveStorageGate
      extend ActiveSupport::Concern

      included do
        before_action :enforce_content_security!
      end

      private

      def enforce_content_security!
        return unless @blob.present?

        unless BetterTogether::ContentSecurity::BlobAccessPolicy.public_proxy_allowed?(@blob)
          head :not_found
          return
        end

        # Look up attachment context to determine whether auth enforcement is needed.
        # Non-scannable blobs (no scans_attachment config) return nil and skip auth.
        context = BetterTogether::ContentSecurity::BlobAccessPolicy.attachment_context_for(@blob)
        return unless context

        record = context.fetch(:attachment).record
        return if record.respond_to?(:privacy_public?) && record.privacy_public?

        enforce_authenticated_access!(record)
      rescue Pundit::NotAuthorizedError
        head :forbidden
      end

      def enforce_authenticated_access!(record)
        if respond_to?(:user_signed_in?, true) && user_signed_in?
          enforce_user_download_policy!(record)
        elsif robot_with_read_private_content_scope?
          nil # Robot with sufficient scope — scope-based authz applies; Pundit skipped.
        else
          head :unauthorized
        end
      end

      def enforce_user_download_policy!(record)
        policy = Pundit.policy(current_user, record)
        return head(:forbidden) unless policy.respond_to?(:download?)

        head :forbidden unless policy.download?
      end

      def robot_with_read_private_content_scope?
        respond_to?(:robot_authenticated?, true) &&
          robot_authenticated? &&
          current_robot&.allows_bot_scope?('read_private_content')
      end
    end
  end
end
