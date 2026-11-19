# frozen_string_literal: true

# Enrolls every ActiveStorage attachment (engine or host app) in malware scanning
# when the `attachments` surface is enabled. ActiveStorage::Attachment is Rails
# core, so one include covers all models; see Quotas for the same pattern.
Rails.application.config.to_prepare do
  attachment = ActiveStorage::Attachment
  hooked = attachment.ancestors.any? { |mod| mod.name == 'BetterTogether::ContentSecurity::AttachmentHook' }
  attachment.include(BetterTogether::ContentSecurity::AttachmentHook) unless hooked
end
