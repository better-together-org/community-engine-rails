module BetterTogether
  class Geography::RegionSettlement < ApplicationRecord
    belongs_to :region, class_name: 'BetterTogether::Geography::Region'
    belongs_to :settlement, class_name: 'BetterTogether::Geography::Settlement'
  end
end
