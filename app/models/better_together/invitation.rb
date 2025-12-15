# frozen_string_literal: true

module BetterTogether
  # Used to invite someone to something (platform, community, etc)
  class Invitation < ApplicationRecord # rubocop:todo Metrics/ClassLength
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
    validate :prevent_duplicate_invitations

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

    # This method should be set by the controller when explicitly resending to declined invitations
    def force_resend?
      @force_resend == true
    end

    attr_writer :force_resend

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

    def prevent_duplicate_invitations
      return unless invitable.present?

      existing_invitation = find_existing_invitation
      return unless existing_invitation

      handle_duplicate_invitation(existing_invitation)
    end

    def handle_duplicate_invitation(existing_invitation)
      case existing_invitation.status
      when 'pending'
        handle_pending_duplicate
      when 'accepted'
        handle_accepted_duplicate
      when 'declined'
        handle_declined_duplicate
      end
    end

    def handle_pending_duplicate
      field = for_existing_user? ? :invitee : :invitee_email
      errors.add(field, 'has already been invited and the invitation is still pending')
    end

    def handle_accepted_duplicate
      field = for_existing_user? ? :invitee : :invitee_email
      resource_type = invitable.class.name.demodulize.downcase
      errors.add(field, "has already accepted an invitation to this #{resource_type}")
    end

    def handle_declined_duplicate
      return if force_resend?

      field = for_existing_user? ? :invitee : :invitee_email
      errors.add(field, 'has previously declined an invitation. Use the resend option to send a new invitation.')
    end

    def find_existing_invitation
      scope = self.class.where(invitable:)
      scope = scope.where.not(id:) if persisted?

      if for_existing_user?
        scope.find_by(invitee:)
      else
        scope.find_by(invitee_email:)
      end
    end
  end
end
