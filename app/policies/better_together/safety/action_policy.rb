# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for moderator safety actions.
    class ActionPolicy < ApplicationPolicy
      def create?
        can_review_safety_disclosures?
      end

      def update?
        create?
      end
    end
  end
end
