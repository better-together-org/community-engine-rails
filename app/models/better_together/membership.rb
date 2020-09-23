module BetterTogether
  class Membership < ApplicationRecord
    belongs_to  :joinable,
                polymorphic: true
    belongs_to  :member,
                polymorphic: true
    belongs_to  :role
  end
end
