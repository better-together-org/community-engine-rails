# frozen_string_literal: true

# Wires the quota framework (Phase 5a, shadow mode; see BetterTogether::Quotas for
# the full facade). ActiveStorage::Attachment is Rails core, not scoped to this
# engine or any one host app, so patching it here (same to_prepare pattern already
# used for ActiveStorage::DirectUploadsController) covers every attachment with
# zero per-model or per-host-app code.
Rails.application.config.to_prepare do
  ActiveStorage::Attachment.include(BetterTogether::Quotas::AttachmentTracking)
  ActiveStorage::DirectUploadsController.include(BetterTogether::Quotas::DirectUploadReservation)

  # DetachMany is a plain Ruby class (not reloaded), while DetachManyTracking is
  # reloadable, so on a code reload a fresh module object would otherwise be stacked
  # on top of the old one; skip the prepend once any version of it is present.
  detach_many = ActiveStorage::Attached::Changes::DetachMany
  unless detach_many.ancestors.any? { |mod| mod.name == 'BetterTogether::Quotas::DetachManyTracking' }
    detach_many.prepend(BetterTogether::Quotas::DetachManyTracking)
  end

  # Force-constantize the known quota types so Type.register (at the bottom of each
  # type file) runs eagerly on every boot/reload, not only when eager_load is true.
  %w[
    BetterTogether::Quotas::Types::MediaStorage
    BetterTogether::Quotas::Types::AiTranslationTokens
  ].each(&:constantize)
end
