# frozen_string_literal: true

module BetterTogether
  module Geography
    class Region < ApplicationRecord # rubocop:todo Style/Documentation
      include Geospatial::One
      include Identifier
      include Protected
      include PrimaryCommunity

      has_community

      slugged :name

      belongs_to :country, class_name: 'BetterTogether::Geography::Country', optional: true
      belongs_to :state, class_name: 'BetterTogether::Geography::State', optional: true

      has_many :region_settlements, class_name: 'BetterTogether::Geography::RegionSettlement'
      has_many :settlements, through: :region_settlements, source: :settlement

      def to_s
        name
      end
    end
  end
end
