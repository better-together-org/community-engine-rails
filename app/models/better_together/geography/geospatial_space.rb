# frozen_string_literal: true

module BetterTogether
  module Geography
    class GeospatialSpace < ApplicationRecord
      include Positioned
      include PrimaryFlag

      belongs_to :geospatial, polymorphic: true
      belongs_to :space, class_name: 'BetterTogether::Geography::Space'
    end
  end
end
