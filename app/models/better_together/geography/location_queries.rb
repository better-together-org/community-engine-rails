# frozen_string_literal: true

module BetterTogether
  module Geography
    # SQL for "which records of a model are located in a place". A record is in a place when its explicit
    # location is the place itself, or a placeable (an address or building) that has been resolved to sit
    # within the place (HierarchyResolutionJob records that placement as a LocatableLocation of the address).
    module LocationQueries
      module_function

      # Relation of locatable ids of +model+ placed in +place+ directly or through a contained placeable.
      def locatable_ids(model, place)
        model.where(id: direct_ids(model, place)).or(model.where(id: contained_ids(model, place))).select(:id)
      end

      def direct_ids(model, place)
        table = LocatableLocation.arel_table
        LocatableLocation
          .where(locatable_type: model.base_class.name, location_type: place.class.base_class.name,
                 location_id: place.id)
          .select(table[:locatable_id])
      end

      def contained_ids(model, place)
        table = LocatableLocation.arel_table
        placement = table.alias('placements')
        LocatableLocation.where(locatable_type: model.base_class.name)
                         .joins(table.join(placement).on(contained_in(placement, table, place)).join_sources)
                         .select(table[:locatable_id])
      end

      # The placeable's own placement row (alias) points at +place+.
      def contained_in(placement, table, place)
        placement[:locatable_type].eq(table[:location_type]).and(placement[:locatable_id].eq(table[:location_id]))
                                  .and(placement[:location_type].eq(place.class.base_class.name))
                                  .and(placement[:location_id].eq(place.id))
      end

      # Ids of +model+ records that have an explicit location row of any kind.
      def explicitly_located_ids(model)
        LocatableLocation.where(locatable_type: model.base_class.name).select(:locatable_id)
      end
    end
  end
end
