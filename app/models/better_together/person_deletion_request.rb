# frozen_string_literal: true

module BetterTogether
  # Stores member-submitted deletion requests for later human review.
  class PersonDeletionRequest < PlatformRecord
    self.table_name = 'better_together_person_deletion_requests'

    STATUS_VALUES = {
      pending: 'pending',
      cancelled: 'cancelled',
      approved: 'approved',
      rejected: 'rejected'
    }.freeze

    belongs_to :person, class_name: 'BetterTogether::Person', inverse_of: :person_deletion_requests
    # Captures the platform where the deletion was requested — audit trail only.
    belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true
    belongs_to :reviewed_by,
               class_name: 'BetterTogether::Person',
               optional: true,
               inverse_of: :reviewed_person_deletion_requests

    has_many :person_purge_audits,
             class_name: 'BetterTogether::PersonPurgeAudit',
             dependent: :nullify,
             inverse_of: :person_deletion_request

    enum :status, STATUS_VALUES, default: :pending, validate: true

    validates :requested_at, presence: true
    validates :status, presence: true
    validate :single_active_request, on: :create

    scope :latest_first, -> { order(requested_at: :desc, created_at: :desc) }
    scope :active, -> { where(status: :pending) }

    def cancel!
      update!(status: :cancelled, resolved_at: Time.current)
    end

    def approve!(reviewed_by:, reviewer_notes: nil)
      update!(
        status: :approved,
        reviewed_by:,
        reviewer_notes:,
        resolved_at: Time.current
      )
    end

    def reject!(reviewed_by:, reviewer_notes: nil)
      update!(
        status: :rejected,
        reviewed_by:,
        reviewer_notes:,
        resolved_at: Time.current
      )
    end

    private

    def single_active_request
      return unless self.class.active.where(person_id: person_id).exists?

      errors.add(:base, 'already has a pending deletion request')
    end

    def capture_current_platform
      self.platform ||= Current.platform || BetterTogether::Platform.find_by(host: true)
    end
  end
end
