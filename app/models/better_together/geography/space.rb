# frozen_string_literal: true

module BetterTogether
  module Geography
    # This module defines geographical entities and their related functionalities.
    # The `Geography::Space` class represents a geographical space with attributes
    # such as elevation, latitude, and longitude. It includes validation for these
    # attributes to ensure they fall within acceptable ranges.
    class Space < ApplicationRecord
      include Creatable
      include Identifier

      has_many :geospatial_spaces

      validates :elevation, numericality: true, allow_nil: true
      validates :latitude, numericality: { greater_than_or_equal_to:  -90, less_than_or_equal_to:  90 }
      validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

      def self.permitted_attributes(id: false, destroy: false, exclude_extra: false)
        super + %i[longitude latitude elevation]
      end

      def geocoded?
        latitude.present? && longitude.present?
      end

      def to_leaflet_point
        return nil unless geocoded?

        {
          lat: latitude,
          lng: longitude,
          elevation: elevation
        }
      end
    end
  end
end
