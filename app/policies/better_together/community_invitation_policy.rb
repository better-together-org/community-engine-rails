# frozen_string_literal: true

module BetterTogether
  class CommunityInvitationPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def create?
      return false unless user.present?

      # Community organizers (coordinators, facilitators) and platform managers can invite people
      return true if allowed_on_community?

      permitted_to?('manage_platform')
    end

    def destroy?
      user.present? && record.status == 'pending' && allowed_on_community?
    end

    def resend?
      user.present? && record.status == 'pending' && allowed_on_community?
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        return scope.none unless user.present?
        return scope.all if permitted_to?('manage_platform')

        # Users see invitations for communities they can manage
        community_invitations_scope
      end

      private

      def community_invitations_scope
        scope.joins(:invitable)
             .where(better_together_invitations: { invitable_type: 'BetterTogether::Community' })
             .where(manageable_communities_condition)
      end

      def manageable_communities_condition
        manageable_community_ids = user.person&.member_communities&.joins(:person_community_memberships)
                                       &.where(
                                         better_together_person_community_memberships: {
                                           member_id: user.person.id
                                         }
                                       )
                                       &.joins('JOIN better_together_roles ON better_together_roles.id = better_together_person_community_memberships.role_id') # rubocop:disable Layout/LineLength
                                       &.where(
                                         'better_together_roles.identifier IN (?)',
                                         %w[community_coordinator community_facilitator]
                                       )&.pluck(:id) || []

        return '1=0' if manageable_community_ids.empty? # No access if no manageable communities

        "better_together_communities.id IN (#{manageable_community_ids.join(',')})"
      end
    end

    private

    def allowed_on_community?
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
