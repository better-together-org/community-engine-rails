module BetterTogether
  class Role < ApplicationRecord
    include Mobility

    translates :name
    translates :description, type: :text

    def self.reserved
      where(reserved: true)
    end
  end
end
