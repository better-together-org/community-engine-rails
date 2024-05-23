module BetterTogether
  class Geography::Region < ApplicationRecord
    include Identifier
    include Protected
    include PrimaryCommunity

    slugged :name

    belongs_to :country, class_name: 'BetterTogether::Geography::Country', optional: true
    belongs_to :state, class_name: 'BetterTogether::Geography::State', optional: true

    def to_s
      name
    end
  end
end
