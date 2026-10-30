# frozen_string_literal: true

module BetterTogether
  # Resolves the record an ActiveStorage::Attachment "really" belongs to: an inline
  # Trix/ActionText image attachment's own `record` is the ActionText::RichText join
  # row, not the owning Post/Page/Hero. Shared with ActiveStorageSecurity's
  # resolve_authorizable_record, which previously duplicated this same rule.
  module ActiveStorageAttachmentRecord
    module_function

    def resolve(record)
      return record.record if record.is_a?(ActionText::RichText)

      record
    rescue StandardError
      nil
    end
  end
end
