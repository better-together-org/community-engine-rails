module BetterTogether
  module Geography
    class Continent < ApplicationRecord
      include Identifier
      include Protected

      # slugged :name

      has_many :country_continents, class_name: 'BetterTogether::Geography::CountryContinent', dependent: :destroy
      has_many :countries, through: :country_continents, class_name: 'BetterTogether::Geography::Country'

      translates :name
      translates :description, type: :text

      validates :name, presence: true

      def to_s
        name
      end
    end
  end
end
