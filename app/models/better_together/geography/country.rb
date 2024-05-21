module BetterTogether
  module Geography
    class Country < ApplicationRecord
      include Identifier
      include Protected

      # slugged :name

      translates :name
      translates :description, type: :text

      has_many :country_continents, class_name: 'BetterTogether::Geography::CountryContinent', dependent: :destroy
      has_many :continents, through: :country_continents, class_name: 'BetterTogether::Geography::Continent'
      has_many :states, class_name: 'BetterTogether::Geography::State', dependent: :nullify

      validates :name, presence: true

      def to_s
        name
      end
    end
  end
end
