# frozen_string_literal: true

module BetterTogether
  module Geography
    module Locatable
      # The `located_in(place)` scope for any model with a has_one `location` (a LocatableLocation).
      # Included by Locatable::One; a host model with its own has_one can include it directly.
      module LocatedIn
        extend ActiveSupport::Concern

        included do
          class_attribute :location_inheritance, instance_accessor: false
        end

        class_methods do
          # Records located in +place+ (a settlement, region, address, ...). A record with its own location
          # counts only through that location; one without counts through the record it inherits from.
          def located_in(place)
            direct = where(id: LocationQueries.locatable_ids(self, place))
            inherited = inherited_located_in(place)
            inherited ? direct.or(inherited) : direct
          end

          # A record without a location of its own takes the place of +association+ (a post takes its community's).
          def inherit_location_from(association)
            self.location_inheritance = association
          end

          private

          def inherited_located_in(place)
            reflection = location_inheritance && reflect_on_association(location_inheritance)
            return unless reflection

            parent_ids = reflection.klass.located_in(place).select(:id)
            where.not(id: LocationQueries.explicitly_located_ids(self)).where(reflection.foreign_key => parent_ids)
          end
        end

        # The record's own place, else the place it inherits, else nil. A location that is only free text
        # still counts as the record's own, so it does not inherit.
        def effective_location
          return location.location if location

          parent = self.class.location_inheritance && public_send(self.class.location_inheritance)
          parent&.effective_location
        end
      end
    end
  end
end
