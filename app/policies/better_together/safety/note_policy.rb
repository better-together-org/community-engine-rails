# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for safety notes.
    class NotePolicy < ApplicationPolicy
      def create?
        agent&.permitted_to?('manage_platform')
      end
    end
  end
end
