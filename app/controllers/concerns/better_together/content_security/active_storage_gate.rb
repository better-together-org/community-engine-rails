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
        unless respond_to?(:user_signed_in?, true) && user_signed_in?
          head :unauthorized
          return
        end

        policy = Pundit.policy(current_user, record)
        return unless policy.respond_to?(:download?)

        head :forbidden unless policy.download?
      end
    end
  end
end
