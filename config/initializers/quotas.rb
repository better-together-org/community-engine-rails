# frozen_string_literal: true

# Wires the quota framework (Phase 5a, shadow mode; see BetterTogether::Quotas for
# the full facade). ActiveStorage::Attachment is Rails core, not scoped to this
# engine or any one host app, so patching it here (same to_prepare pattern already
# used for ActiveStorage::DirectUploadsController) covers every attachment with
# zero per-model or per-host-app code.
Rails.application.config.to_prepare do
  ActiveStorage::Attachment.include(BetterTogether::Quotas::AttachmentTracking)
  ActiveStorage::DirectUploadsController.include(BetterTogether::Quotas::DirectUploadReservation)

  # Force-constantize the known quota types so Type.register (at the bottom of each
  # type file) runs eagerly on every boot/reload, not only when eager_load is true.
  %w[
    BetterTogether::Quotas::Types::MediaStorage
    BetterTogether::Quotas::Types::AiTranslationTokens
  ].each(&:constantize)
end
