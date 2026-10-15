# frozen_string_literal: true

module BetterTogether
  module Geography
    # Fetches the OpenStreetMap boundary polygon for one geography record (Continent/Country/State/Region/
    # Settlement) from Nominatim, as GeoJSON.
    #
    # Two ways in, most exact first:
    # 1. the OSM object already recorded on the record's space (`metadata['boundary_source']`, or an `osm`
    #    hint in the seed data): a /lookup by id, so a re-import always gets the same feature;
    # 2. a /search by name with the record's parents appended ("Corner Brook, Newfoundland and Labrador, Canada"),
    #    taking the first result that actually has polygon geometry, preferring administrative boundaries.
    #
    # Polygons are simplified by Nominatim (`polygon_threshold`, degrees) so a stored boundary is a few KB, not
    # a few hundred. Returns a Result; #data is nil when nothing usable was found and #reason says why.
    class BoundaryFetcher
      POLYGON_TYPES = %w[Polygon MultiPolygon].freeze
      DEFAULT_THRESHOLD = 0.0005 # about 50 m
      SEARCH_LIMIT = 5

      Result = Struct.new(:data, :reason, :via, keyword_init: true)

      def self.call(record, threshold: nil)
        new(record, threshold:).call
      end

      def initialize(record, threshold: nil)
        @record = record
        @threshold = threshold || ENV.fetch('NOMINATIM_POLYGON_THRESHOLD', DEFAULT_THRESHOLD).to_f
      end

      def call
        result = by_osm_id
        return result if result&.data

        by_search
      end

      # Query text for the name search: the record plus its parents, narrowest first.
      def search_text
        [@record.to_s, parent_name(:state), parent_name(:country)].compact_blank.uniq.join(', ')
      end

      private

      def by_osm_id
        id = NominatimOsmLookup.osm_id_for(source['osm_type'], source['osm_id'])
        return unless id

        found = pick(NominatimOsmLookup.new.search(id, params: polygon_params))
        found ? Result.new(data: found, via: :osm_id) : nil
      end

      def by_search
        results = Geocoder.search(search_text, params: polygon_params.merge(limit: SEARCH_LIMIT))
        found = pick(results)
        return Result.new(data: found, via: :search) if found

        Result.new(reason: results.empty? ? :no_result : :no_polygon, via: :search)
      end

      def polygon_params
        { polygon_geojson: 1, polygon_threshold: @threshold }
      end

      def pick(results)
        polygons = results.map(&:data).select { |data| POLYGON_TYPES.include?(data.dig('geojson', 'type')) }
        polygons.find { |data| (data['category'] || data['class']) == 'boundary' } || polygons.first
      end

      def source
        @source ||= @record.space&.metadata.to_h['boundary_source'].to_h
      end

      def parent_name(name)
        @record.public_send(name).to_s.presence if @record.respond_to?(name)
      end
    end
  end
end
