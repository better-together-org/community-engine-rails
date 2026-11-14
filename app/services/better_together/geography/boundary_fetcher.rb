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
      ACCEPTED_CLASSES = %w[boundary place natural].freeze
      BBOX_MARGIN = 0.1 # of the box size, for a seed point that sits near an edge

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
        polygons = results.map(&:data).select { |data| usable?(data) }
        polygons.find { |data| kind(data) == 'boundary' } || polygons.first
      end

      def usable?(data)
        POLYGON_TYPES.include?(data.dig('geojson', 'type')) && ACCEPTED_CLASSES.include?(kind(data)) &&
          covers_seed_point?(data['boundingbox'])
      end

      def kind(data)
        data['category'] || data['class']
      end

      # Nominatim's boundingbox is [south, north, west, east] as strings. No coordinates or no box: nothing to check.
      def covers_seed_point?(box)
        space = @record.space
        return true unless box && space&.latitude && space.longitude

        south, north, west, east = box.map(&:to_f)
        within?(space.latitude, south, north) && within?(space.longitude, west, east)
      end

      def within?(value, low, high)
        margin = (high - low) * BBOX_MARGIN
        value.between?(low - margin, high + margin)
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
