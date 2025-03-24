# frozen_string_literal: true

module BetterTogether
  module Geography
    # This module defines geographical entities and their related functionalities.
    # The `Geography::Space` class represents a geographical space with attributes
    # such as elevation, latitude, and longitude. It includes validation for these
    # attributes to ensure they fall within acceptable ranges. The class also
    # supports polymorphic associations with other geospatial entities.
    class Space < ApplicationRecord
      include Creatable
      include Identifier

      validates :elevation, numericality: true, allow_nil: true
      validates :latitude, numericality: { greater_than_or_equal_to:  -90, less_than_or_equal_to:  90 }
      validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

      belongs_to :geospatial, polymorphic: true, optional: true
    end
  end
end
