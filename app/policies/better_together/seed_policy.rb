# frozen_string_literal: true

module BetterTogether
  class SeedPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      host_platform_manager?
    end

    def show?
      host_platform_manager?
    end

    def create?
      host_platform_manager?
    end

    def new?
      create?
    end

    def update?
      host_platform_manager?
    end

    def edit?
      update?
    end

    def download?
      show?
    end

    def destroy?
      host_platform_manager?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        if host_platform_manager?
          scope.latest_first
        else
          scope.none
        end
      end
    end
  end
end
