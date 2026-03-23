# frozen_string_literal: true

module BetterTogether
  # Gates ActiveStorage blob/representation proxy routes through the CE auth model.
  #
  # Included into ActiveStorage proxy and redirect controllers via the
  # active_storage_security initializer. Runs after ActiveStorage::SetBlob sets @blob.
  #
  # Gate logic (fail-closed):
  #   1. Blob not attached to any record → require authentication (no orphaned public blobs).
  #   2. Blob is attached to a record with Privacy#privacy_public? → allow unauthenticated.
  #   3. Otherwise require the user to be signed in.
  #   4. If the attachment record has a Pundit policy responding to #download? → enforce it.
  #
  # Handles signed blob IDs and signed blob/variation IDs (representations).
  # @blob is set by ActiveStorage::SetBlob or ActiveStorage::SetBlobAndVariation before
  # this filter runs because before_actions added via `include` append to the chain.
  module ActiveStorageSecurity
    extend ActiveSupport::Concern

    included do
      before_action :authorize_blob_access
    end

    private

    def authorize_blob_access
      return unless @blob.present?

      record = attachment_record_for(@blob)

      return if publicly_accessible?(record)

      unless user_signed_in?
        head :unauthorized
        return
      end

      enforce_download_policy!(record) if record
    end

    # Returns the first attachment's record, or nil on any error.
    # A blob may be attached to many records (e.g. via mirror/shared uploads);
    # we check the first one. All attachments of a shared blob should have the
    # same privacy model in practice.
    def attachment_record_for(blob)
      blob.attachments.first&.record
    rescue StandardError
      nil
    end

    def publicly_accessible?(record)
      record.respond_to?(:privacy_public?) && record.privacy_public?
    end

    # Runs the record's Pundit policy #download? check if it exists.
    # Renders 403 on denial; silently passes if the policy has no download? method
    # (other controllers are responsible for those resource types).
    def enforce_download_policy!(record)
      policy = Pundit.policy(current_user, record)
      return unless policy.respond_to?(:download?)
      return if policy.download?

      head :forbidden
    rescue Pundit::NotAuthorizedError
      head :forbidden
    end
  end
end
