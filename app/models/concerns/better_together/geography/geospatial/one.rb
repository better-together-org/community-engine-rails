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

          # Provides #geocoded? (via the geocoder gem) for every includer — cheap,
          # makes no network calls on its own. Stays unconditional; only the
          # auto-scheduling callbacks below are opt-in via .geocodes_self.
          geocoded_by :geocoding_string
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

          # Opt-in: registers automatic self-geocoding (schedule_geocoding after
          # create/update) off this model's own #geocoding_string. Call explicitly in
          # includers that should be geocoded from their own attributes. Models that
          # geocode via an associated record (Infrastructure::Building via its
          # `address`) or delegate geospatial data entirely to another record
          # (Infrastructure::Floor/Room via their `building`) must NOT call this.
          def geocodes_self
            after_create :schedule_geocoding
            after_update :schedule_geocoding
          end
        end

        def geocoding_string
          to_s
        end

        def schedule_geocoding
          return unless should_geocode?

          BetterTogether::Geography::GeocodingJob.perform_later(self)
        end

        def should_geocode?
          return false if geocoding_string.blank?

          # space.reload # in case it has been geocoded since last load

          (changed? or !geocoded?)
        end

        def geospatial_space
          super || build_geospatial_space(geospatial: self)
        end

        def space
          attrs = {}
          attrs[:creator_id] = creator_id if respond_to?(:creator_id)
          super || build_space(attrs)
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
