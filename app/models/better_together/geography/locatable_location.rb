# frozen_string_literal: true

module BetterTogether
  module Geography
    # Join record between polymorphic locatable and polymorphic location
    class LocatableLocation < ApplicationRecord
      include Creatable

      belongs_to :locatable, polymorphic: true
      belongs_to :location, polymorphic: true, optional: true

      def self.permitted_attributes(id: false, destroy: false)
        super + %i[name locatable_id locatable_type location_id location_type]
      end

      def to_s
        name || id
      end
    end
  end
end
