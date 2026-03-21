# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for safety cases.
    class CasePolicy < ApplicationPolicy
      def index?
        platform_manager?
      end

      def show?
        platform_manager?
      end

      def update?
        platform_manager?
      end

      # Limits case visibility to platform managers.
      class Scope < ApplicationPolicy::Scope
        def resolve
          return scope.all if agent&.permitted_to?('manage_platform')

          scope.none
        end
      end

      private

      def platform_manager?
        agent&.permitted_to?('manage_platform')
      end
    end
  end
end
