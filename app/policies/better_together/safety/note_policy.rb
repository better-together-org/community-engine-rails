# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for safety notes.
    class NotePolicy < PlatformRecordPolicy
      def create?
        platform = (record.respond_to?(:platform) ? record.platform : nil) || current_platform
        can_review_safety_disclosures?(platform)
      end
    end
  end
end
