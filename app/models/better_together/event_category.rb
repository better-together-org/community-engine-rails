# frozen_string_literal: true

module BetterTogether
  # Categories specifically for events
  class EventCategory < Category
    has_many :events, through: :categorizations, source: :categorizable, source_type: 'BetterTogether::Event'
  end
end
