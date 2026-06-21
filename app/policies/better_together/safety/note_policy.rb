# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for safety notes.
    class NotePolicy < PlatformRecordPolicy
      def create?
        can_review_safety_disclosures?
      end
    end
  end
end
