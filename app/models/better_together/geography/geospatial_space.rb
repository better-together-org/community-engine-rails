# frozen_string_literal: true

module BetterTogether
  module Geography
    # Join record between a polymorphic geospatial record and a Space
    class GeospatialSpace < ApplicationRecord
      include Positioned
      include PrimaryFlag

      belongs_to :geospatial, polymorphic: true
      belongs_to :space, class_name: 'BetterTogether::Geography::Space'
    end
  end
end
