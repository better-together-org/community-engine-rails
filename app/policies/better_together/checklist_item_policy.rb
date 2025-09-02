# frozen_string_literal: true

module BetterTogether
  class ChecklistItemPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def show?
      # If parent checklist is public or user can update checklist
      record.checklist.privacy_public? || ChecklistPolicy.new(user, record.checklist).update?
    end

    def create?
      ChecklistPolicy.new(user, record.checklist).update?
    end

    def update?
      ChecklistPolicy.new(user, record.checklist).update?
    end

    def destroy?
      ChecklistPolicy.new(user, record.checklist).destroy?
    end

    # Permission for bulk reorder endpoint (collection-level)
    def reorder?
      ChecklistPolicy.new(user, record.checklist).update?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
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

            if scope.ancestors.include?(BetterTogether::Creatable)
              query = query.or(table[:creator_id].eq(agent.id))
            end
          end

          result = result.where(query)
        end

        result
      end
    end
  end
end
