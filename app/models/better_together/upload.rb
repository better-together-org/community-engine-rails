# frozen_string_literal: true

module BetterTogether
  # Represents an uploaded file
  class Upload < PlatformRecord
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
    has_many :content_security_subjects, class_name: 'BetterTogether::ContentSecurity::Subject',
                                         as: :subject, inverse_of: :subject, dependent: :destroy

    after_commit :sync_legacy_content_security_subject, on: %i[create update]

    def content_security_item
      BetterTogether::ContentSecurity::Item.for_attachment(self, :file).find_by(blob_id: file.blob_id) if file.attached?
    end

    def content_security_releasable?
      BetterTogether::ContentSecurity::BlobAccessPolicy.download_allowed_for_record?(self, :file)
    end

    # Legacy UI helpers still expect a Subject-backed review record for the attached file.
    def file_content_security_subject
      return unless upload_content_security_enabled?

      content_security_subjects.find_by(attachment_name: 'file') if file.attached?
    end

    def file_content_security_downloadable?
      return content_security_releasable? unless upload_content_security_enabled?

      subject = file_content_security_subject
      return subject.released_for_human_access? unless subject.nil?

      content_security_releasable?
    end

    def file_content_security_held?
      return false unless upload_content_security_enabled?

      subject = file_content_security_subject
      return subject.held_for_review? unless subject.nil?

      item = content_security_item
      return false if item.nil?

      !item.releasable?
    end

    def to_param
      id
    end

    private

    def sync_legacy_content_security_subject
      return unless upload_content_security_enabled?

      BetterTogether::ContentSecurity::AttachmentSubjectSync.new(
        record: self,
        attachment_name: :file,
        source_surface: :uploads
      ).call
    end

    def upload_content_security_enabled?
      BetterTogether::ContentSecurity::Configuration.enabled? &&
        BetterTogether::ContentSecurity::Configuration.enabled_for_surface?(:uploads)
    end
  end
end
