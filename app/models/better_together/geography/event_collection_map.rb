# frozen_string_literal: true

module BetterTogether
  module Geography
    # Custom collection map for events
    # This class is used to create a map of events that have an assigned
    # structured or geocoded location. It inherits from LocatableMap and
    # overrides the records method to return every event with a location,
    # ordered by their creation date.
    #
    # @see LocatableMap
    #
    # @example
    #   events_map = EventCollectionMap.new
    #   events_map.records # => returns a collection of events ordered by creation date
    #
    # @note This class is used for creating a map of events and rendered on the events index view.
    class EventCollectionMap < LocatableMap
      def self.mappable_class
        ::BetterTogether::Event
      end

      # Preloads through `location: :space` (a 3rd level beyond the join used for
      # filtering) so #leaflet_points/#spaces below — which read
      # location.location.space via Locatable::One — don't N+1 per event. `space` is a
      # has_one :through :geospatial_space (from Geospatial::One, included by every
      # directly-geocoded Placeable target: Address/Building/Settlement/Region), so
      # Rails preloads the intermediate geospatial_space transparently for those.
      #
      # Infrastructure::Floor/Room have no independent space of their own — they
      # delegate #space to their building (see their own model comments for why
      # that's a plain delegate, not a real has_one :through :building: Rails
      # doesn't reliably resolve a has_one :through chained through another has_one
      # :through). `[:space, { building: :space }]` covers both shapes in one
      # preload: Rails only applies each entry to the polymorphic subtypes that
      # actually have a matching reflection, so this works across a mixed result
      # set without raising for any type (confirmed for all 6 Placeable types).
      def self.records
        mappable_class.joins(:location)
                      .includes(location: { location: [:space, { building: :space }] })
                      .order(created_at: :desc)
      end

      def records
        @records ||= self.class.records
      end

      def leaflet_points
        @leaflet_points ||= records.flat_map(&:leaflet_points)
      end

      def spaces
        @spaces ||= records.flat_map(&:spaces).compact.uniq
      end
    end
  end
end
