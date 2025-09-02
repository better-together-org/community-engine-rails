# frozen_string_literal: true

module BetterTogether
  # Used to invite someone to something (platform, community, etc)
  class Invitation < ApplicationRecord
    has_secure_token :token

    belongs_to :invitable,
               polymorphic: true
    belongs_to :inviter,
               polymorphic: true
    belongs_to :invitee,
               polymorphic: true,
               optional: true
    belongs_to :role,
               optional: true

    enum :status, {
      accepted: 'accepted',
      declined: 'declined',
      pending: 'pending'
    }

    scope :pending, -> { where(status: 'pending') }
    scope :accepted, -> { where(status: 'accepted') }
    scope :not_expired, -> { where('valid_until IS NULL OR valid_until >= ?', Time.current) }
    scope :expired, -> { where('valid_until IS NOT NULL AND valid_until < ?', Time.current) }

    before_validation :set_accepted_timestamp, if: :will_save_change_to_status?

    validates :token, presence: true, uniqueness: true
    validates :status, inclusion: { in: statuses.values }

    private

    def set_accepted_timestamp
      self.accepted_at = Time.current if status == 'accepted'
    end
  end
end
