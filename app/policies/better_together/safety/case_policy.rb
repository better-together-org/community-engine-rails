# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for safety cases.
    class CasePolicy < PlatformRecordPolicy
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
      class Scope < PlatformRecordPolicy::Scope
        def resolve
          return platform_scoped if permitted_to?('manage_platform_safety', current_platform)

          scope.none
        end
      end

      private

      def safety_reviewer?
        platform = (record.respond_to?(:platform) ? record.platform : nil) || current_platform
        can_review_safety_disclosures?(platform)
      end
    end
  end
end
