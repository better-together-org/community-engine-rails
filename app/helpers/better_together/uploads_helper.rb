# frozen_string_literal: true

module BetterTogether
  # helper methods for file uploads
  module UploadsHelper
    def total_upload_size(uploads)
      number_to_human_size(uploads.sum(&:byte_size))
    end

    def upload_content_security_badge_class(upload)
      subject = upload.file_content_security_subject
      return 'text-bg-success' if subject.blank? || subject.released_for_human_access?

      return 'text-bg-danger' if subject.aggregate_verdict.in?(%w[blocked quarantined])

      'text-bg-warning'
    end

    def upload_content_security_badge_text(upload)
      subject = upload.file_content_security_subject
      return t('better_together.uploads.content_security.badge.clean', default: 'Ready') if subject.blank? || subject.released_for_human_access?
      return restricted_upload_badge_text if subject.aggregate_verdict.in?(%w[blocked quarantined])

      t('better_together.uploads.content_security.badge.review_required', default: 'Under review')
    end

    def upload_content_security_status_text(upload)
      subject = upload.file_content_security_subject
      return clean_upload_status_text if subject.blank? || subject.released_for_human_access?
      return restricted_upload_status_text if subject.aggregate_verdict.in?(%w[blocked quarantined])

      t(
        'better_together.uploads.content_security.status.review_required',
        default: 'This upload is being reviewed before it can be inserted into rich text or shared.'
      )
    end

    private

    def restricted_upload_badge_text
      t('better_together.uploads.content_security.badge.restricted', default: 'Restricted')
    end

    def clean_upload_status_text
      t(
        'better_together.uploads.content_security.status.clean',
        default: 'This upload is ready to insert or share.'
      )
    end

    def restricted_upload_status_text
      t(
        'better_together.uploads.content_security.status.restricted',
        default: 'This upload is currently restricted while a reviewer checks it.'
      )
    end
  end
end
