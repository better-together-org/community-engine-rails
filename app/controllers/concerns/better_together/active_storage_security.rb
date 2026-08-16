# frozen_string_literal: true

module BetterTogether
  # Gates ActiveStorage blob/representation proxy routes through the CE auth model.
  #
  # Included into ActiveStorage proxy and redirect controllers via the
  # active_storage_security initializer. Runs after ActiveStorage::SetBlob sets @blob.
  #
  # Gate logic (fail-closed):
  #   0. The blob's actual byte content must match its declared content_type (see
  #      #verify_content_signature) -- runs first, before any auth/privacy check, and
  #      before any representation/variant generation is ever attempted.
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

    # Bytes needed for Marcel to reliably sniff a magic-byte signature. Every format this
    # app accepts (images, PDFs, common documents) resolves from well under this window --
    # avoids downloading a potentially large file just to check its header.
    CONTENT_SIGNATURE_SNIFF_BYTES = 4096

    included do
      before_action :verify_content_signature
      before_action :authorize_blob_access
      after_action :apply_media_cache_headers
    end

    private

    # ActiveStorage::DirectUploadsController#create only ever receives metadata (filename,
    # byte_size, checksum, declared content_type) -- the browser uploads bytes straight to
    # the storage service via a presigned URL, bypassing Rails entirely, so there is nothing
    # to inspect at creation time. This is the earliest point real bytes exist to check
    # against what was declared, and it runs before representation/variant generation ever
    # invokes libvips -- making explicit and universal what libvips' own untrusted-loader
    # denylist otherwise only does implicitly, and only for the specific loaders it happens
    # to block.
    def verify_content_signature
      return unless @blob.present?

      sniffed_type = sniff_content_type(@blob)
      return if sniffed_type.nil? # sniffing failed open -- don't block on our own I/O error
      return if sniffed_type == @blob.content_type

      Rails.logger.warn(
        '[BetterTogether::ActiveStorageSecurity] content signature mismatch for blob ' \
        "#{@blob.id}: declared #{@blob.content_type.inspect}, sniffed #{sniffed_type.inspect}"
      )
      head :unprocessable_entity
    end

    # Deliberately uses Marcel::Magic.by_magic directly, not the higher-level
    # Marcel::MimeType.for -- that convenience method also blends in the filename and
    # declared_type as fallback signals when magic-byte detection is inconclusive, which
    # would let an attacker's own filename/content-type claim influence the very check
    # meant to catch a mismatch between the two. Pure byte-content detection only; nil
    # (unrecognized magic signature) is handled by the caller as fail-open, not a mismatch.
    def sniff_content_type(blob)
      chunk = blob.download_chunk(0...CONTENT_SIGNATURE_SNIFF_BYTES)
      Marcel::Magic.by_magic(StringIO.new(chunk))&.type
    rescue StandardError => e
      Rails.logger.warn(
        "[BetterTogether::ActiveStorageSecurity] content signature sniff failed for blob #{blob.id}: #{e.class}: #{e.message}"
      )
      nil
    end

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

    def apply_media_cache_headers
      return unless @blob.present?

      policy = media_cache_policy_for_blob
      response.set_header('X-BTS-Cache-Scope', policy.cache_scope)

      return if policy.public?

      response.headers['Cache-Control'] = BetterTogether::MediaCachePolicy::PRIVATE_CACHE_CONTROL
    end

    def media_cache_policy_for_blob
      BetterTogether::MediaCachePolicy.for_blob(@blob)
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
