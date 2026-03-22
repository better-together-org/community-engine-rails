# frozen_string_literal: true

module BetterTogether
  # Invitation for Communities using the polymorphic invitations table
  class CommunityInvitation < Invitation
    validate :invitee_uniqueness_for_community

    # Convenience helpers (invitable is the community)
    def community
      invitable
    end

    def after_accept!(invitee_person: nil)
      person = invitee_person || resolve_invitee_person
      return unless person && community

      # Create community membership with the specified role (default to community_member)
      ensure_community_membership!(person)
    end

    def url_for_review
      BetterTogether::Engine.routes.url_helpers.community_url(
        invitable.slug,
        locale: locale,
        invitation_token: token
      )
    end

    private

    def invitee_uniqueness_for_community
      return unless community

      check_duplicate_person_invitation
      check_duplicate_email_invitation
    end

    def ensure_community_membership!(person)
      return unless community

      # Use the role specified in the invitation, or default to community_member
      target_role = role || BetterTogether::Role.find_by(identifier: 'community_member')

      # Create community membership for the invitee
      community.person_community_memberships.find_or_create_by!(
        member: person,
        role: target_role
      )
    end

    def check_duplicate_person_invitation
      return unless invitee.present?

      existing = community.invitations.where(invitee:, status: %w[pending accepted])
                          .where.not(id: id)
      errors.add(:invitee, 'has already been invited to this community') if existing.exists?
    end

    def check_duplicate_email_invitation
      return unless invitee_email.present?

      existing = community.invitations.where(invitee_email:, status: %w[pending accepted])
                          .where.not(id: id)
      errors.add(:invitee_email, 'has already been invited to this community') if existing.exists?
    end
  end
end
