# frozen_string_literal: true

module BetterTogether
  module Geography
    # Gates the location picker lookup. Which records a person may see is decided by the
    # LocatableLocation.available_<type>_for scopes, so this only requires a signed-in person.
    class LocatableLocationPolicy < ApplicationPolicy
      def available?
        agent.present?
      end
    end
  end
end
