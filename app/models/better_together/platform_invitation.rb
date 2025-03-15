# frozen_string_literal: true

module BetterTogether
  # Allows for platform managers to invite new people to register to the platform
  class PlatformInvitation < ApplicationRecord
    has_secure_token

    STATUS_VALUES = {
      accepted: 'accepted',
      pending: 'pending'
    }.freeze

    belongs_to :invitee,
               class_name: '::BetterTogether::Person',
               foreign_key: 'invitee_id',
               optional: true
    belongs_to :inviter,
               class_name: '::BetterTogether::Person',
               foreign_key: 'inviter_id'
    belongs_to :invitable,
               class_name: '::BetterTogether::Platform',
               foreign_key: 'invitable_id'
    belongs_to :community_role,
               class_name: '::BetterTogether::Role',
               foreign_key: 'community_role_id'
    belongs_to :platform_role,
               class_name: '::BetterTogether::Role',
               foreign_key: 'platform_role_id',
               optional: true

    enum status: STATUS_VALUES, _prefix: :status

    has_rich_text :greeting, encrypted: true

    validates :invitee_email, uniqueness: { scope: :invitable_id, allow_nil: true }
    validates :invitee_email, uniqueness: { scope: :invitable_id, allow_nil: true, allow_blank: true }
    validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
    validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }
    validates :token, uniqueness: true
    validate :valid_status_transition, if: :status_changed?

    before_validation :set_accepted_timestamp

    # Callback to queue the email job after creation
    after_create_commit :queue_invitation_email, if: :should_send_email?

    scope :pending, -> { where(status: STATUS_VALUES[:pending]) }
    scope :accepted, -> { where(status: STATUS_VALUES[:accepted]) }
    # TODO: Check expired scope to ensure that it includes those wit no value for valid_until
    scope :expired, -> { where('valid_until < ?', Time.current) }

    # TODO: add 'not expired' scope to find only invitations that are available

    def self.load_all_subclasses
      [self, GuestAccess].each(&:connection) # Add all known subclasses here
    end

    def accept!(invitee:, save_record: true)
      self.invitee = invitee
      self.status = STATUS_VALUES[:accepted]
      save! if save_record
    end

    def expired?
      valid_until.present? && valid_until < Time.current
    end

    def invitee_email=(email)
      new_value = email&.strip&.downcase
      super(new_value.present? ? new_value : nil)
    end

    def registers_user?
      true
    end

    def url
      BetterTogether::Engine.routes.url_helpers.new_user_registration_url(invitation_code: token)
    end

    def to_s
      "[#{self.class.model_name.human}] - #{id}"
    end

    private

    def set_accepted_timestamp
      return unless status_changed?

      self.accepted_at = Time.current if status == 'accepted'
    end

    def queue_invitation_email
      BetterTogether::PlatformInvitationMailerJob.perform_later(id)
    end

    def should_send_email?
      invitee_email.present? && !email_recently_sent? && !throttled?
    end

    def email_recently_sent?
      last_sent.present? && last_sent > 15.minutes.ago
    end

    def throttled?
      BetterTogether::PlatformInvitation.where(inviter:, created_at: 15.minutes.ago..Time.current).count > 10
    end

    def valid_status_transition
      valid_transitions = {
        'pending' => %w[accepted],
        'accepted' => []
      }

      return unless status_was.present? && !valid_transitions[status_was].include?(status)

      errors.add(:status, "cannot transition from #{status_was} to #{status}")
    end
  end
end
