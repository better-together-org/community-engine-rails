# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for moderator safety actions.
    class ActionPolicy < ApplicationPolicy
      def create?
        agent&.permitted_to?('manage_platform')
      end

      def update?
        create?
      end
    end
  end
end
