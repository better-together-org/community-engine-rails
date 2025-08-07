# frozen_string_literal: true

module BetterTogether
  module Geography
    # Join record between a polymorphic geospatial record and a Space
    class GeospatialSpace < ApplicationRecord
      include Positioned
      include PrimaryFlag

      belongs_to :geospatial, polymorphic: true
      belongs_to :space, class_name: 'BetterTogether::Geography::Space'
      accepts_nested_attributes_for :space

      def self.permitted_attributes(id: false, destroy: false, exclude_extra: false)
        super + [{
          space_attributes: BetterTogether::Geography::Space.permitted_attributes(id: true, destroy: true)
        }]
      end

      def space
        super || build_space(creator_id: geospatial&.creator_id, identifier: SecureRandom.alphanumeric(10))
      end
    end
  end
end
