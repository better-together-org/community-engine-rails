# frozen_string_literal: true

module BetterTogether
  # Authorization policy for community invitations
  # Defines who can view, create, update, and manage community invitations
  class CommunityInvitationPolicy < InvitationPolicy
    INVITE_PERMISSIONS = %w[invite_community_members manage_community_members manage_community_roles].freeze

    # An inviter keeps their own pending invitation: they can see, resend and withdraw it.
    def destroy?
      super || own_pending_invitation?
    end

    def resend?
      super || own_pending_invitation?
    end

    # Scope class for filtering community invitations based on user permissions
    class Scope < InvitationPolicy::Scope
      private

      def filtered_invitations_scope
        return scope.none unless agent

        communities = invitable_type_condition(BetterTogether::Community)
        communities.where(invitable_id: manageable_community_ids).or(own_pending_invitations(communities))
      end

      # Only the actor's own memberships count, so a plain member never inherits another member's grant.
      def manageable_community_ids
        BetterTogether::PersonCommunityMembership
          .joins(role: { role_resource_permissions: :resource_permission })
          .where(member_id: agent.id, status: 'active')
          .where(better_together_resource_permissions: { identifier: INVITE_PERMISSIONS })
          .select(:joinable_id)
      end

      def own_pending_invitations(communities)
        communities.where(inviter_type: agent.class.name, inviter_id: agent.id, status: 'pending')
      end
    end

    private

    def own_pending_invitation?
      user.present? && record.status_pending? && record.inviter == agent
    end

    def allowed_on_invitable?
      community = record.invitable
      return false unless community.is_a?(BetterTogether::Community)

      # Check for specific invite/manage permissions on this community
      permitted_to?('invite_community_members', community) ||
        permitted_to?('manage_community_members', community) ||
        permitted_to?('manage_community_roles', community)
    end
  end
end
