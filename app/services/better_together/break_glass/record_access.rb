# frozen_string_literal: true

module BetterTogether
  module BreakGlass
    # Writes the audit row for one read made under a grant. Policies call this when a grant is what allowed
    # the read, so the trail records use, not just existence.
    class RecordAccess
      def self.call(grant:, actor:, action:)
        grant.events.create!(event_type: 'accessed', actor:, platform: grant.platform, detail: { action: action.to_s })
      end
    end
  end
end
