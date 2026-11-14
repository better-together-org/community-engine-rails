# frozen_string_literal: true

module BetterTogether
  # Rescues variant/representation processing failures raised by ActiveStorage's own
  # redirect/proxy controllers (e.g. libvips refusing to load a file through an
  # untrusted-loader match such as `matload`). Without this, an ambiguous or malformed
  # blob throws a hard 500 on every subsequent thumbnail/representation request instead
  # of degrading gracefully.
  #
  # Included into ActiveStorage proxy and redirect controllers via the
  # active_storage_variant_error_handling initializer.
  module ActiveStorageVariantErrorHandling
    extend ActiveSupport::Concern

    included do
      # String (not constant): ruby-vips loads lazily on first real use, and libvips
      # isn't guaranteed present at boot (e.g. some CI runners). rescue_from resolves
      # string handlers lazily against the raised exception, so this never forces an
      # eager `require "vips"`.
      rescue_from 'Vips::Error', with: :handle_variant_processing_error
    end

    private

    def handle_variant_processing_error(exception)
      Rails.logger.warn(
        '[BetterTogether::ActiveStorage] variant processing failed for blob ' \
        "#{@blob&.id}: #{exception.class}: #{exception.message}"
      )
      head :unprocessable_entity
    end
  end
end
