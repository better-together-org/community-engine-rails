# frozen_string_literal: true

module BetterTogether
  module Geography
    class RegionSettlement < ApplicationRecord
      belongs_to :region, class_name: 'BetterTogether::Geography::Region'
      belongs_to :settlement, class_name: 'BetterTogether::Geography::Settlement'
    end
  end
end
