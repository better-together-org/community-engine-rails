# frozen_string_literal: true

module BetterTogether
  # Represents an uploaded file
  class Upload < ApplicationRecord
    include Creatable
    include Identifier
    include Privacy
    include Translatable

    has_one_attached :file
    has_many :content_security_subjects,
             as: :subject,
             class_name: 'BetterTogether::ContentSecurity::Subject',
             dependent: :destroy,
             inverse_of: :subject

    delegate :attached?, :byte_size, :content_type, :download, :filename, :url, to: :file

    translates :name, type: :string
    translates :description, backend: :action_text

    include RemoveableAttachment

    after_commit :sync_file_content_security_subject

    def to_param
      id
    end

    def file_content_security_subject
      content_security_subjects.find_by(attachment_name: 'file')
    end

    def file_content_security_downloadable?
      file_content_security_subject.nil? || file_content_security_subject.released_for_human_access?
    end

    private

    def sync_file_content_security_subject
      BetterTogether::ContentSecurity::AttachmentSubjectSync.new(
        record: self,
        attachment_name: :file,
        source_surface: 'ce_upload_file'
      ).call
    end
  end
end
