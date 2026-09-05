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
    #
    # When @communities is pre-loaded by the index action (with buildings+space+address
    # already eager-loaded), the helper injects it via loaded_collection= so the map
    # reuses the same records without a second query.
    class CommunityCollectionMap < CommunityMap
      attr_writer :loaded_collection

      def self.records
        mappable_class
          .joins(buildings: [:space])
          .preload(buildings: %i[space address])
          .order(created_at: :desc)
      end

      def records
        @records ||= @loaded_collection || self.class.records
      end

      def spaces
        @spaces ||= records.flat_map do |community|
          if community.association(:buildings).loaded?
            community.buildings.filter_map(&:space)
          else
            community.spaces
          end
        end.compact.uniq
      end

      def leaflet_points
        @leaflet_points ||= records.flat_map do |community|
          if community.association(:buildings).loaded?
            preloaded_leaflet_points(community)
          else
            community.leaflet_points
          end
        end.compact.uniq
      end

      private

      def preloaded_leaflet_points(community)
        community.buildings.filter_map do |building|
          next unless building.space.present?

          point = building.to_leaflet_point
          next if point.nil?

          build_leaflet_point(point, community, building.address)
        end
      end

      def build_leaflet_point(point, community, address)
        place_label = address&.text_label.present? ? " - #{address.text_label}" : nil
        place_url = community_place_url(community)
        place_link = "<a href='#{place_url}' class='text-decoration-none'>" \
                     "<strong>#{community.name}#{place_label}</strong></a>"
        address_label = address&.to_formatted_s(excluded: [:display_label])

        point.merge(label: place_link, popup_html: "#{place_link}<br>#{address_label}")
      end

      def community_place_url(community)
        BetterTogether::Engine.routes.url_helpers.polymorphic_path(community, locale: I18n.locale)
      rescue NoMethodError
        Rails.application.routes.url_helpers.polymorphic_path(community, locale: I18n.locale)
      end
    end
  end
end
