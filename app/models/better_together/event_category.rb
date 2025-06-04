module BetterTogether
  class EventCategory < Category
    has_many :events, through: :categorizations, source: :categorizable, source_type: 'BetterTogether::Event'
  end
end
