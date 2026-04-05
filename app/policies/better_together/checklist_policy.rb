# frozen_string_literal: true

module BetterTogether
  class ChecklistPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def show?
      # Checklists do not currently resolve a scoped community, so community privacy
      # does not broaden visibility beyond creator/manager access.
      public_or_member_scoped_community?(record) || update?
    end

    def index?
      # Let policy_scope handle visibility; index access is allowed (scope filters public/private)
      true
    end

    def create?
      platform_checklist_manager?
    end

    def update?
      platform_checklist_manager? || (agent.present? && record.creator == agent)
    end

    def destroy?
      platform_checklist_manager? && !record.protected?
    end

    def completion_status?
      update?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        result = scope.with_translations.order(created_at: :desc)

        table = scope.arel_table

        if scope.ancestors.include?(BetterTogether::Privacy)
          query = visible_privacy_query(table)

          if platform_checklist_manager?
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

      private

      def platform_checklist_manager?
        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
      end
    end

    private

    def platform_checklist_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end
  end
end
