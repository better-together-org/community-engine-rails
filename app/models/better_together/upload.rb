# frozen_string_literal: true

module BetterTogether
  # Represents an uploaded file
  class Upload < ApplicationRecord
    include BetterTogether::ContentSecurity::ScannableAttachment
    include Creatable
    include Identifier
    include Privacy
    include Translatable

    has_one_attached :file

    delegate :attached?, :byte_size, :content_type, :download, :filename, :url, to: :file

    translates :name, type: :string
    translates :description, backend: :action_text

    include RemoveableAttachment

    scans_attachment :file, surface: :uploads

    def content_security_item
      BetterTogether::ContentSecurity::Item.for_attachment(self, :file).find_by(blob_id: file.blob_id) if file.attached?
    end

    def content_security_releasable?
      BetterTogether::ContentSecurity::BlobAccessPolicy.download_allowed_for_record?(self, :file)
    end

    def to_param
      id
    end
  end
end
