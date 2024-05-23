module BetterTogether
  module Geography
    class State < ApplicationRecord
      include Identifier
      include Protected
      include PrimaryCommunity

      slugged :name

      belongs_to :country, class_name: 'BetterTogether::Geography::Country'

      has_many :regions, class_name: 'BetterTogether::Geography::Region'
      has_many :settlements, class_name: 'BetterTogether::Geography::Settlement'

      def to_s
        name
      end
    end
  end
end
