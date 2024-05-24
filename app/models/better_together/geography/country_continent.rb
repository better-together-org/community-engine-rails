# frozen_string_literal: true

module BetterTogether
  module Geography
    class CountryContinent < ApplicationRecord # rubocop:todo Style/Documentation
      belongs_to :country, class_name: 'BetterTogether::Geography::Country'
      belongs_to :continent, class_name: 'BetterTogether::Geography::Continent'

      validates :country_id, presence: true
      validates :continent_id, presence: true
    end
  end
end
