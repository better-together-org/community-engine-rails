# frozen_string_literal: true

module BetterTogether
  module Geography
    module Geospatial
      module One # rubocop:todo Style/Documentation
        extend ActiveSupport::Concern

        included do
          has_one :geospatial_space, class_name: 'BetterTogether::Geography::GeospatialSpace', as: :geospatial,
                                     dependent: :destroy
          has_one :space, through: :geospatial_space

          accepts_nested_attributes_for :geospatial_space, :space, reject_if: :all_blank, allow_destroy: true

          delegate :latitude, :longitude, :elevation, :geocoded, to: :space, allow_nil: true
          delegate :latitude=, :longitude=, :elevation=, to: :space
          delegate :latitude_changed?, :longitude_changed?, :elevation_changed?, to: :space, allow_nil: true
        end

        class_methods do
          def extra_permitted_attributes
            super + [{
              geospatial_space_attributes:
                BetterTogether::Geography::GeospatialSpace.permitted_attributes(id: true,
                                                                                destroy: true),
              space_attributes: BetterTogether::Geography::Space.permitted_attributes(id: true, destroy: true)
            }]
          end
        end

        def geospatial_space
          super || build_geospatial_space(geospatial: self)
        end

        def space
          super || build_space(creator_id: creator_id)
        end

        def to_leaflet_point
          return nil unless geocoded?

          {
            lat: latitude,
            lng: longitude,
            elevation: elevation,
            label: to_s
          }
        end
      end
    end
  end
end
