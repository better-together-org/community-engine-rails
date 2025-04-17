# frozen_string_literal: true

module BetterTogether
  module Geography
    class Country < ApplicationRecord # rubocop:todo Style/Documentation
      include Geospatial::One
      include Identifier
      include Protected
      include PrimaryCommunity

      slugged :name

      has_many :country_continents, class_name: 'BetterTogether::Geography::CountryContinent', dependent: :destroy
      has_many :continents, through: :country_continents, class_name: 'BetterTogether::Geography::Continent'
      has_many :states, class_name: 'BetterTogether::Geography::State', dependent: :nullify

      def to_s
        name
      end
    end
  end
end
