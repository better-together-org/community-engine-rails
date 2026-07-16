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

      def self.records
        mappable_class.joins(:location).includes(location: :location).order(created_at: :desc)
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
