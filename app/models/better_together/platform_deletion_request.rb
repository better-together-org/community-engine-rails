# frozen_string_literal: true

module BetterTogether
  # A request from the last steward of a platform to have the platform removed. It is the
  # alternative to deleting that steward's own account, which would leave nobody in charge.
  # Host stewards receive it through the task feature (subscribe to the event below).
  class PlatformDeletionRequest < ApplicationRecord
    self.table_name = 'better_together_platform_deletion_requests'

    EVENT = 'platform_deletion_requested.better_together'

    belongs_to :platform, class_name: 'BetterTogether::Platform'
    belongs_to :requested_by, class_name: 'BetterTogether::Person', inverse_of: :platform_deletion_requests
    belongs_to :reviewed_by, class_name: 'BetterTogether::Person', optional: true,
                             inverse_of: :reviewed_platform_deletion_requests

    enum :status, { pending: 'pending', cancelled: 'cancelled', approved: 'approved', rejected: 'rejected' },
         default: :pending, validate: true

    validates :requested_at, presence: true
    validate :requester_is_steward, on: :create
    validate :single_pending_request, on: :create

    scope :latest_first, -> { order(requested_at: :desc, created_at: :desc) }

    after_create_commit :announce

    def cancel!
      update!(status: :cancelled, resolved_at: Time.current)
    end

    private

    def requester_is_steward
      return if platform&.steward?(requested_by)

      errors.add(:requested_by, :invalid)
    end

    def single_pending_request
      return unless platform_id && self.class.pending.exists?(platform_id:)

      errors.add(:base, :taken)
    end

    def announce
      ActiveSupport::Notifications.instrument(EVENT, platform_id:, request_id: id, requested_by_id:)
    end
  end
end
