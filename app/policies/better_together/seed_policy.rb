# frozen_string_literal: true

module BetterTogether
  class SeedPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      permitted_to?('manage_platform')
    end

    def show?
      permitted_to?('manage_platform')
    end

    def create?
      permitted_to?('manage_platform')
    end

    def new?
      create?
    end

    def update?
      permitted_to?('manage_platform')
    end

    def edit?
      update?
    end

    def download?
      show?
    end

    def destroy?
      permitted_to?('manage_platform')
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        if permitted_to?('manage_platform')
          scope.latest_first
        else
          scope.none
        end
      end
    end
  end
end
