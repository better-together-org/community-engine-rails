# frozen_string_literal: true

module BetterTogether
  # Authorization policy for community invitations
  # Defines who can view, create, update, and manage community invitations
  class CommunityInvitationPolicy < InvitationPolicy
    # Scope class for filtering community invitations based on user permissions
    class Scope < InvitationPolicy::Scope
      private

      def filtered_invitations_scope
        return scope.none unless agent

        invitable_type_condition(BetterTogether::Community)
          .where(invitable_id: manageable_communities_relation)
      end

      def manageable_communities_relation
        agent.member_communities
             .joins(person_community_memberships: { role: { role_resource_permissions: :resource_permission } })
             .where(
               better_together_person_community_memberships: { member_id: agent.id },
               better_together_resource_permissions: { identifier: 'invite_community_members' }
             )
      end
    end

    private

    def allowed_on_invitable?
      community = record.invitable
      return false unless community.is_a?(BetterTogether::Community)

      # Platform managers may act across communities
      return true if permitted_to?('manage_platform')

      # Check for specific invite_community_members permission on this community
      permitted_to?('invite_community_members', community)
    end
  end
end
