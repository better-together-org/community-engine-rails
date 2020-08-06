module BetterTogether
  class Authorable < ApplicationRecord
    belongs_to :authorable,
               polymorphic: true,
               required: true

    def to_s
      authorable.to_s
    end
  end
end
