# frozen_string_literal: true

module BetterTogether
  # Verifies a blob's actual byte content matches its declared content_type before any
  # representation/variant generation is attempted, so a maliciously-mistyped upload
  # (e.g. declared image/png, real bytes something else entirely) never reaches libvips.
  #
  # ActiveStorage::DirectUploadsController#create only ever receives metadata (filename,
  # byte_size, checksum, declared content_type) -- the browser uploads bytes straight to
  # the storage service via a presigned URL, bypassing Rails entirely, so there is
  # nothing to inspect at creation time. This is the earliest point real bytes exist to
  # check against what was declared.
  #
  # Included into ActiveStorage proxy and redirect controllers via the
  # active_storage_content_signature initializer. Runs after ActiveStorage::SetBlob or
  # ActiveStorage::SetBlobAndVariation sets @blob, before any representation is built.
  module ActiveStorageContentSignature
    extend ActiveSupport::Concern

    # Bytes needed for Marcel to reliably sniff a magic-byte signature. Every format this
    # app accepts (images, PDFs, common documents) resolves from well under this window --
    # avoids downloading a potentially large file just to check its header.
    CONTENT_SIGNATURE_SNIFF_BYTES = 4096

    included do
      before_action :verify_content_signature
    end

    private

    def verify_content_signature
      return unless @blob.present?

      sniffed_type = sniff_content_type(@blob)
      return if sniffed_type.nil? # sniffing failed open -- don't block on our own I/O error
      return if sniffed_type == @blob.content_type

      Rails.logger.warn(
        '[BetterTogether::ActiveStorageContentSignature] content signature mismatch for blob ' \
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
        "[BetterTogether::ActiveStorageContentSignature] content signature sniff failed for blob #{blob.id}: #{e.class}: #{e.message}"
      )
      nil
    end
  end
end
