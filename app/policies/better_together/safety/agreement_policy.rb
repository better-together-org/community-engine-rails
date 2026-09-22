# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for restorative agreements.
    class AgreementPolicy < PlatformRecordPolicy
      def create?
        platform = (record.respond_to?(:platform) ? record.platform : nil) || current_platform
        can_review_safety_disclosures?(platform)
      end

      def update?
        create?
      end
    end
  end
end
