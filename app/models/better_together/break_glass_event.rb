# frozen_string_literal: true

module BetterTogether
  # One line in the append-only audit trail of a break-glass grant. Rows are never updated or destroyed.
  class BreakGlassEvent < PlatformRecord
    EVENT_TYPES = %w[requested revoked accessed].freeze

    belongs_to :break_glass_grant, class_name: 'BetterTogether::BreakGlassGrant', inverse_of: :events
    belongs_to :actor, class_name: 'BetterTogether::Person', optional: true

    validates :event_type, inclusion: { in: EVENT_TYPES }

    before_destroy { throw :abort }

    def readonly?
      persisted? || super
    end
  end
end
