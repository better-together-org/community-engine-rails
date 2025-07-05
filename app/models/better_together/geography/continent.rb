# frozen_string_literal: true

module BetterTogether
  module Geography
    class Continent < ApplicationRecord # rubocop:todo Style/Documentation
      include Geospatial::One
      include Identifier
      include Protected
      include PrimaryCommunity

      has_community

      slugged :name

      has_many :country_continents, class_name: 'BetterTogether::Geography::CountryContinent', dependent: :destroy
      has_many :countries, through: :country_continents, class_name: 'BetterTogether::Geography::Country'

      def to_s
        name
      end
    end
  end
end
