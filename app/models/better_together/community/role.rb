module BetterTogether
  module Community
    class Role < ApplicationRecord
      include Mobility
      include BetterTogetherId

      translates :name
      translates :description, type: :text

      def self.reserved
        where(reserved: true)
      end
    end
  end
end
