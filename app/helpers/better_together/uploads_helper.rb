# frozen_string_literal: true

module BetterTogether
  # helper methods for file uploads
  module UploadsHelper
    def total_upload_size(uploads)
      number_to_human_size(uploads.sum(&:byte_size))
    end

    def upload_content_security_state(upload)
      @upload_security_state_cache ||= {}
      @upload_security_state_cache[upload.id] ||= begin
        subject = upload.content_security_subjects.detect { |s| s.attachment_name == 'file' }
        if subject.blank? || subject.released_for_human_access?
          'clean'
        elsif subject.aggregate_verdict.in?(%w[blocked quarantined])
          'restricted'
        else
          'review_required'
        end
      end
    end

    def upload_content_security_counts(uploads)
      counts = Hash.new(0)

      uploads.each do |upload|
        counts[upload_content_security_state(upload)] += 1
      end

      counts
    end

    def upload_content_security_badge_class(upload)
      case upload_content_security_state(upload)
      when 'clean'
        'text-bg-success'
      when 'restricted'
        'text-bg-danger'
      else
        'text-bg-warning'
      end
    end

    def upload_content_security_badge_text(upload)
      case upload_content_security_state(upload)
      when 'clean'
        t('better_together.uploads.content_security.badge.clean', default: 'Ready')
      when 'restricted'
        restricted_upload_badge_text
      else
        t('better_together.uploads.content_security.badge.review_required', default: 'Under review')
      end
    end

    def upload_content_security_status_text(upload)
      case upload_content_security_state(upload)
      when 'clean'
        clean_upload_status_text
      when 'restricted'
        restricted_upload_status_text
      else
        t(
          'better_together.uploads.content_security.status.review_required',
          default: 'This upload is being reviewed before it can be inserted into rich text or shared.'
        )
      end
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
