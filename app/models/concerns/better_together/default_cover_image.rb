# frozen_string_literal: true

module BetterTogether
  # Keeps a generated cover image available as a fallback: when the record's cover is cleared (or replaced and then
  # removed), the stored default is attached again as the cover. Generated covers are marked in the blob metadata so
  # callers can tell them from uploads. Include after the cover_image attachment is declared.
  module DefaultCoverImage
    extend ActiveSupport::Concern

    included do
      # Declared before the default attachment: after_commit callbacks run in reverse order, so this runs after
      # Active Storage has uploaded a default attached in the same save and can copy it.
      after_commit :restore_default_cover_image, on: %i[create update]

      has_one_attached :default_cover_image
      # After every attachment is declared, so RemoveableAttachment covers them all (cover_image must already exist).
      include BetterTogether::RemoveableAttachment
    end

    def generated_cover?
      cover_image.attached? && cover_image.blob.metadata['generated'] == true
    end

    private

    def restore_default_cover_image
      return if cover_image.attached? || !default_cover_image.attached?

      self.remove_cover_image = nil
      cover_image.attach(copy_of(default_cover_image.blob))
    end

    def copy_of(blob)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(blob.download), filename: blob.filename.to_s, content_type: blob.content_type,
        metadata: { 'generated' => true }
      )
    end
  end
end
