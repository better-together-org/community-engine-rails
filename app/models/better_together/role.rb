module BetterTogether
  class Role < ApplicationRecord
    include Mobility

    translates :name
    translates :description, type: :text

    validates :name,
              presence: true

    validates :sort_order,
              presence: true,
              uniqueness: true

    before_validation do
      throw(:abort) if self.sort_order.present?
      self.sort_order =
        if self.class.maximum(:sort_order)
          self.class.maximum(:sort_order) + 1
        else
          1
        end
    end

    def self.reserved
      where(reserved: true)
    end

    def to_s
      name
    end
  end
end
