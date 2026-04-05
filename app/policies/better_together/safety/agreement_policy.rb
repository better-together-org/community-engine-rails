# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for restorative agreements.
    class AgreementPolicy < ApplicationPolicy
      def create?
        can_review_safety_disclosures?
      end

      def update?
        create?
      end
    end
  end
end
