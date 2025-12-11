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

    STATUS_VALUES = {
      pending: 'pending',
      accepted: 'accepted',
      declined: 'declined'
    }.freeze

    enum :status, STATUS_VALUES, prefix: :status

    scope :pending, -> { where(status: 'pending') }
    scope :accepted, -> { where(status: 'accepted') }
    scope :not_expired, -> { where('valid_until IS NULL OR valid_until >= ?', Time.current) }
    scope :expired, -> { where('valid_until IS NOT NULL AND valid_until < ?', Time.current) }
    scope :for_existing_users, -> { where.not(invitee: nil) }
    scope :for_email_addresses, -> { where(invitee: nil).where.not(invitee_email: [nil, '']) }

    before_validation :ensure_token_present
    before_validation :set_accepted_timestamp, if: :will_save_change_to_status?

    validates :token, presence: true, uniqueness: true
    validates :status, inclusion: { in: statuses.values }
    validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
    validate :invitee_presence

    # Common invitation actions
    def accept!(invitee_person: nil)
      self.status = STATUS_VALUES[:accepted]
      save!
      after_accept!(invitee_person:)
    end

    def decline!
      self.status = STATUS_VALUES[:declined]
      save!
    end

    # Helper method to determine invitation type
    def invitation_type
      return :person if invitee.present?
      return :email if invitee_email.present?

      :unknown
    end

    # Check if this is an invitation for an existing user
    def for_existing_user?
      invitation_type == :person
    end

    # Check if this is an email invitation
    def for_email?
      invitation_type == :email
    end

    # Template method - subclasses should override
    def after_accept!(invitee_person: nil)
      # Override in subclasses
    end

    # Template method - subclasses should override
    def url_for_review
      raise NotImplementedError, 'Subclasses must implement url_for_review'
    end

    private

    def ensure_token_present
      return if token.present?

      self.token = self.class.generate_unique_secure_token
    end

    def resolve_invitee_person
      return invitee if invitee.is_a?(BetterTogether::Person)

      nil
    end

    def invitee_presence
      return unless invitee.blank? && self[:invitee_email].to_s.strip.blank?

      errors.add(:base, 'Either invitee or invitee_email must be present')
    end

    def set_accepted_timestamp
      self.accepted_at = Time.current if status == 'accepted'
    end
  end
end
