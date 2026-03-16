# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::MembershipRequest.
    #
    # Key difference from base RequestPolicy:
    # - create? is open to the public (unauthenticated visitors can submit requests)
    # - manage actions are restricted to platform/community managers
    class MembershipRequestPolicy < RequestPolicy
      # Anyone may submit a membership request — including unauthenticated visitors.
      def create? = true
      alias new? create?

      def show?
        return true if user.present? && agent.present? && record.creator_id == agent.id

        permitted_to?('manage_platform') || community_manager?
      end

      def update?
        return false if record.respond_to?(:agreements) && record.agreements.exists?

        permitted_to?('manage_platform') || community_manager?
      end
      alias edit? update?

      def destroy?
        return false if record.respond_to?(:agreements) && record.agreements.exists?

        permitted_to?('manage_platform') || community_manager?
      end

      # Platform managers and community managers may approve open requests.
      def approve?
        return false unless record.status_open?

        permitted_to?('manage_platform') || community_manager?
      end

      # Platform managers and community managers may decline open requests.
      def decline?
        return false unless record.status_open?

        permitted_to?('manage_platform') || community_manager?
      end

      class Scope < RequestPolicy::Scope # rubocop:todo Style/Documentation
        def resolve
          membership_request_scope = scope.where(type: 'BetterTogether::Joatu::MembershipRequest')
          return membership_request_scope if permitted_to?('manage_platform')
          return scope.none unless user.present?

          community_manager_scope(membership_request_scope) ||
            membership_request_scope.where(creator_id: agent&.id)
        end

        private

        def community_manager_scope(base)
          managed_ids = managed_community_ids_for(agent)
          return nil unless managed_ids.any?

          base.where(
            'creator_id = ? OR (target_type = ? AND target_id IN (?))',
            agent.id,
            'BetterTogether::Community',
            managed_ids
          )
        end

        def managed_community_ids_for(person)
          return [] unless person.present?

          ::BetterTogether::PersonCommunityMembership
            .joins(:role)
            .where(member_id: person.id)
            .where(better_together_roles: { identifier: %w[community_manager community_administrator] })
            .pluck(:joinable_id)
        end
      end

      private

      def community_manager?
        return false unless user.present? && record.target.is_a?(::BetterTogether::Community)

        record.target.person_community_memberships
              .joins(:role)
              .where(member_id: agent&.id)
              .where(better_together_roles: { identifier: %w[community_manager community_administrator] })
              .exists?
      end
    end
  end
end
