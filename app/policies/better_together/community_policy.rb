# frozen_string_literal: true

module BetterTogether
  class CommunityPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && permitted_to?('list_community')
    end

    def show?
      (record.privacy_public? || user.present?) && permitted_to?('read_community')
    end

    def create?
      user.present? && permitted_to?('create_community')
    end

    def new?
      create?
    end

    def update?
      user.present? && !record.protected? && permitted_to?('update_community')
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && !record.protected? && !record.host?
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.order(:host, :identifier).where(permitted_query)
      end

      protected

      def permitted_query
        communities_table = ::BetterTogether::Community.arel_table
        person_community_memberships_table = ::BetterTogether::PersonCommunityMembership.arel_table

        # Only list communities that are public and where the current person is a member or a creator
        communities_table[:privacy].eq('public').or(
          communities_table[:id].in(
            person_community_memberships_table.
              where(person_community_memberships_table[:member_id].
              eq(agent.id)).
              project(:joinable_id)
          )
        ).or(
          communities_table[:creator_id].eq(agent.id)
        )
      end
    end
  end
end
