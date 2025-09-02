# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Category for Joatu offers and requests
    class Category < BetterTogether::Category
      has_many :offers, through: :categorizations, source: :categorizable, source_type: 'BetterTogether::Joatu::Offer'
      has_many :requests, through: :categorizations, source: :categorizable, source_type: 'BetterTogether::Joatu::Request'
    end
  end
end
