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
        return true if record.creator_id == agent&.id

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

      class Scope < RequestPolicy::Scope # rubocop:todo Style/Documentation
        def resolve
          return scope.where(type: 'BetterTogether::Joatu::MembershipRequest') if permitted_to?('manage_platform')

          # Unauthenticated submitters have no user session; return records with no
          # creator so JSONAPI can render the newly created record back to them.
          return scope.where(type: 'BetterTogether::Joatu::MembershipRequest', creator_id: nil) unless user.present?

          scope.where(
            type: 'BetterTogether::Joatu::MembershipRequest',
            creator_id: agent&.id
          )
        end
      end

      private

      def community_manager?
        return false unless user.present? && record.target.is_a?(::BetterTogether::Community)

        record.target.person_community_memberships
              .where(member: agent)
              .joins(:role)
              .where(better_together_roles: { identifier: %w[community_manager community_administrator] })
              .exists?
      end
    end
  end
end
