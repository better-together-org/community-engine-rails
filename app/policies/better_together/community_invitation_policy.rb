# frozen_string_literal: true

module BetterTogether
  # Authorization policy for community invitations
  # Defines who can view, create, update, and manage community invitations
  class CommunityInvitationPolicy < InvitationPolicy
    # Scope class for filtering community invitations based on user permissions
    class Scope < InvitationPolicy::Scope
      private

      def filtered_invitations_scope
        invitable_type_condition(BetterTogether::Community)
          .where(manageable_communities_condition)
      end

      def manageable_communities_condition # rubocop:todo Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        return 'FALSE' unless user.person

        manageable_community_ids = find_manageable_community_ids
        return '1=0' if manageable_community_ids.empty? # No access if no manageable communities

        "better_together_communities.id IN (#{manageable_community_ids.join(',')})"
      end

      def find_manageable_community_ids
        member_communities = user.person.member_communities
        return [] unless member_communities

        member_communities_with_management_roles.pluck(:id) || []
      end

      def member_communities_with_management_roles
        member_communities = user.person.member_communities
        member_communities.joins(:person_community_memberships)
                          .where(
                            better_together_person_community_memberships: {
                              member_id: user.person.id
                            }
                          )
                          .joins(management_roles_join_clause)
                          .where(management_roles_condition)
      end

      def management_roles_join_clause
        'JOIN better_together_roles ON better_together_roles.id = better_together_person_community_memberships.role_id'
      end

      def management_roles_condition
        [
          'better_together_roles.identifier IN (?)',
          %w[community_coordinator community_facilitator]
        ]
      end
    end

    private

    def allowed_on_invitable?
      community = record.invitable
      return false unless community.is_a?(BetterTogether::Community)

      # Platform managers may act across communities
      return true if permitted_to?('manage_platform')

      cp = BetterTogether::CommunityPolicy.new(user, community)
      # Community organizers (coordinators, facilitators) can invite members
      cp.update?
    end
  end
end
