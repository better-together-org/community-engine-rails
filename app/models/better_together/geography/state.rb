# frozen_string_literal: true

module BetterTogether
  module Geography
    class State < ApplicationRecord # rubocop:todo Style/Documentation
      include Geospatial::One
      include Identifier
      include Protected
      include PrimaryCommunity

      has_community

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
