# frozen_string_literal: true

module BetterTogether
  # Invitation for Events using the polymorphic invitations table
  class EventInvitation < Invitation
    validate :invitee_uniqueness_for_event

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

    def url_for_review
      BetterTogether::Engine.routes.url_helpers.event_url(
        invitable.slug,
        locale: locale,
        invitation_token: token
      )
    end

    private

    def invitee_uniqueness_for_event
      return unless event

      check_duplicate_person_invitation
      check_duplicate_email_invitation
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

    def check_duplicate_person_invitation
      return unless invitee.present?

      existing = event.invitations.where(invitee:, status: %w[pending accepted])
                      .where.not(id:)
      errors.add(:invitee, 'has already been invited to this event') if existing.exists?
    end

    def check_duplicate_email_invitation
      return unless invitee_email.present?

      existing = event.invitations.where(invitee_email:, status: %w[pending accepted])
                      .where.not(id:)
      errors.add(:invitee_email, 'has already been invited to this event') if existing.exists?
    end
  end
end
