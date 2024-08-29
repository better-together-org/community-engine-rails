# frozen_string_literal: true

module BetterTogether
  # Allows for platform managers to invite new people to register to the platform
  class PlatformInvitation < ApplicationRecord
    has_secure_token

    STATUS_VALUES = {
      accepted: 'accepted',
      declined: 'declined',
      pending: 'pending'
    }.freeze

    belongs_to :invitee,
               class_name: '::BetterTogether::Person',
               foreign_key: 'invitee_id'
    belongs_to :inviter,
               class_name: '::BetterTogether::Person',
               foreign_key: 'inviter_id'
    belongs_to :invitable,
               class_name: '::BetterTogether::Platform',
               foreign_key: 'invitable_id'
    belongs_to :platform_role,
               class_name: '::BetterTogether::Role',
               foreign_key: 'platform_role_id'
    belongs_to :community_role,
               class_name: '::BetterTogether::Role',
               foreign_key: 'community_role_id'

    enum status: STATUS_VALUES, _prefix: :status

    validates :invitee_email, presence: true, uniqueness: { scope: :invitable_id }
    validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
    validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }
    validates :token, uniqueness: true
    validate :valid_status_transition, if: :status_changed?

    before_validation :set_accepted_or_declined_timestamps

    # Callback to queue the email job after creation
    after_create_commit :queue_invitation_email, if: :should_send_email?

    scope :pending, -> { where(status: STATUS_VALUES[:pending]) }
    scope :accepted, -> { where(status: STATUS_VALUES[:accepted]) }
    scope :expired, -> { where('valid_until < ?', Time.current) }

    # Custom Methods

    def expired?
      valid_until.present? && valid_until < Time.current
    end

    private

    def set_accepted_or_declined_timestamps
      return unless status_changed?

      self.accepted_at = Time.current if status == 'accepted'
      self.declined_at = Time.current if status == 'declined'
    end

    def queue_invitation_email
      BetterTogether::PlatformInvitationMailerJob.perform_later(id)
    end

    def should_send_email?
      !email_recently_sent? && !throttled?
    end

    def email_recently_sent?
      last_sent.present? && last_sent > 15.minutes.ago
    end

    def throttled?
      BetterTogether::PlatformInvitation.where(inviter:, created_at: 15.minutes.ago..Time.current).count > 10
    end

    def valid_status_transition
      valid_transitions = {
        'pending' => %w[accepted declined],
        'accepted' => [],
        'declined' => []
      }

      return unless status_was.present? && !valid_transitions[status_was].include?(status)

      errors.add(:status, "cannot transition from #{status_was} to #{status}")
    end
  end
end
