# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for safety cases.
    class CasePolicy < ApplicationPolicy
      def index?
        safety_reviewer?
      end

      def show?
        safety_reviewer?
      end

      def update?
        safety_reviewer?
      end

      # Limits case visibility to platform managers.
      class Scope < ApplicationPolicy::Scope
        def resolve
          return scope.all if permitted_to?('manage_platform_safety')

          scope.none
        end
      end

      private

      def safety_reviewer?
        can_review_safety_disclosures?
      end
    end
  end
end
