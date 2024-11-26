# frozen_string_literal: true

module BetterTogether
  module Geography
    class Settlement < ApplicationRecord
      include Identifier
      include Protected
      include PrimaryCommunity

      slugged :name

      belongs_to :country, class_name: 'BetterTogether::Geography::Country', optional: true
      belongs_to :state, class_name: 'BetterTogether::Geography::State', optional: true

      has_many :region_settlements, class_name: 'BetterTogether::Geography::RegionSettlement'
      has_many :regions, through: :region_settlements, source: :region

      def to_s
        name
      end
    end
  end
end
