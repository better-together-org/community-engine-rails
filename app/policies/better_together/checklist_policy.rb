# frozen_string_literal: true

module BetterTogether
  class ChecklistPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def show?
      # Allow viewing public checklists to everyone, otherwise fall back to update permissions
      record.privacy_public? || update?
    end

    def index?
      # Let policy_scope handle visibility; index access is allowed (scope filters public/private)
      true
    end

    def create?
      permitted_to?('manage_platform')
    end

    def update?
      permitted_to?('manage_platform') || (agent.present? && record.creator == agent)
    end

    def destroy?
      permitted_to?('manage_platform') && !record.protected?
    end

    def completion_status?
      update?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        result = scope.with_translations.order(created_at: :desc)

        table = scope.arel_table

        if scope.ancestors.include?(BetterTogether::Privacy)
          query = table[:privacy].eq('public')

          if permitted_to?('manage_platform')
            query = query.or(table[:privacy].eq('private'))
          elsif agent
            if scope.ancestors.include?(BetterTogether::Joinable) && scope.membership_class.present?
              membership_table = scope.membership_class.arel_table
              query = query.or(
                table[:id].in(
                  membership_table
                    .where(membership_table[:member_id].eq(agent.id))
                    .project(:joinable_id)
                )
              )
            end

            query = query.or(table[:creator_id].eq(agent.id)) if scope.ancestors.include?(BetterTogether::Creatable)
          end

          result = result.where(query)
        end

        result
      end
    end
  end
end
