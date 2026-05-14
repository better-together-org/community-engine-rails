# frozen_string_literal: true

module BetterTogether
  class ShortLinkPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present?
    end

    def show?
      user.present? && creator_or_manager?
    end

    def create?
      user.present?
    end

    def update?
      user.present? && creator_or_manager?
    end

    def destroy?
      user.present? && creator_or_manager?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        if permitted_to?('manage_platform')
          scope.all
        else
          scope.with_creator(agent)
        end
      end
    end

    private

    def creator_or_manager?
      record.creator == agent || permitted_to?('manage_platform')
    end

    def permitted_to?(permission)
      agent&.permitted_to?(permission)
    end
  end
end
