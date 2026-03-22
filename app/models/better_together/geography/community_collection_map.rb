# frozen_string_literal: true

module BetterTogether
  module Geography
    # Custom collection map for communities
    # This class is used to create a map of communities, which are collections of spaces
    # and buildings. It inherits from CommunityMap and overrides the records method to
    # return a collection of communities ordered by their creation date.
    #
    # @see CommunityMap
    #
    # @example
    #   venue_map = CommunityCollectionMap.new
    #   venue_map.records # => returns a collection of communities ordered by creation date
    #
    # @note This class is used for creating maps of communities in the application and
    # rendered on the communities index view.
    class CommunityCollectionMap < CommunityMap
      def self.records
        mappable_class.joins(buildings: [:space]).order(created_at: :desc)
      end

      def leaflet_points
        records.map(&:leaflet_points).flatten.uniq
      end

      def records
        self.class.records
      end

      def spaces
        records.map(&:spaces).flatten.uniq
      end
    end
  end
end
