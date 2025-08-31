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
        scope.with_translations
      end
    end
  end
end
