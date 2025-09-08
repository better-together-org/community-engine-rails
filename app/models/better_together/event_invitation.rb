# frozen_string_literal: true

module BetterTogether
  # Invitation for Events using the polymorphic invitations table
  class EventInvitation < Invitation
    STATUS_VALUES = {
      pending: 'pending',
      accepted: 'accepted',
      declined: 'declined'
    }.freeze

    enum :status, STATUS_VALUES, prefix: :status

    validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
    validate :invitee_presence
    validate :invitee_uniqueness_for_event

    # Ensure token is generated before validation
    before_validation :ensure_token_present

    # Scopes for different invitation types
    scope :for_existing_users, -> { where.not(invitee: nil) }
    scope :for_email_addresses, -> { where(invitee: nil).where.not(invitee_email: [nil, '']) }

    # Convenience helpers (invitable is the event)
    def event
      invitable
    end

    def after_accept!(invitee_person: nil)
      person = invitee_person || resolve_invitee_person
      return unless person && event

      # Ensure the person has community membership for the event's community
      ensure_community_membership!(person)

      attendance = BetterTogether::EventAttendance.find_or_initialize_by(event:, person:)
      attendance.status = 'going'
      attendance.save!
    end

    def accept!(invitee_person: nil)
      self.status = STATUS_VALUES[:accepted]
      save!
      after_accept!(invitee_person:)
    end

    def decline!
      self.status = STATUS_VALUES[:declined]
      save!
    end

    def url_for_review
      BetterTogether::Engine.routes.url_helpers.event_url(
        invitable.slug,
        locale: locale,
        invitation_token: token
      )
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

    def invitee_uniqueness_for_event
      return unless event

      # Check for duplicate person invitation
      if invitee.present?
        existing = event.invitations.where(invitee:, status: %w[pending accepted])
                        .where.not(id:)
        errors.add(:invitee, 'has already been invited to this event') if existing.exists?
      end

      # Check for duplicate email invitation
      return unless invitee_email.present?

      existing = event.invitations.where(invitee_email:, status: %w[pending accepted])
                      .where.not(id:)
      errors.add(:invitee_email, 'has already been invited to this event') if existing.exists?
    end

    def ensure_community_membership!(person)
      community = BetterTogether::Community.find_by(host: true)

      return unless community

      # Create community membership for the invitee
      default_role = BetterTogether::Role.find_by(identifier: 'community_member')
      community.person_community_memberships.find_or_create_by!(
        member: person,
        role: default_role
      )
    end
  end
end
