# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for restorative agreements.
    class AgreementPolicy < ApplicationPolicy
      def create?
        agent&.permitted_to?('manage_platform')
      end

      def update?
        create?
      end
    end
  end
end
