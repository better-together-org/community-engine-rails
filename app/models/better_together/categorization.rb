module BetterTogether
  class Categorization < ApplicationRecord
    belongs_to :category, polymorphic: true
    belongs_to :categorizable, polymorphic: true
  end
end
