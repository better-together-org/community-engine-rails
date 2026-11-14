# frozen_string_literal: true

require 'geocoder/lookups/nominatim'

module BetterTogether
  module Geography
    # Nominatim's /lookup endpoint: fetches OpenStreetMap objects by id ("R2845280", "N123", "W456")
    # instead of searching by name. Geocoder's bundled :nominatim lookup only knows /search and /reverse.
    # Used directly (not registered as a global lookup), so it inherits the host, timeout and User-Agent
    # configured in config/initializers/geocoder.rb.
    class NominatimOsmLookup < Geocoder::Lookup::Nominatim
      OSM_TYPE_PREFIX = { 'node' => 'N', 'way' => 'W', 'relation' => 'R' }.freeze

      def self.osm_id_for(osm_type, osm_id)
        prefix = OSM_TYPE_PREFIX[osm_type.to_s]
        prefix && osm_id.present? ? "#{prefix}#{osm_id}" : nil
      end

      private

      def base_query_url(_query)
        "#{protocol}://#{configured_host}/lookup?"
      end

      def query_url_params(query)
        { format: 'json', addressdetails: '1', 'accept-language': query.language || configuration.language,
          osm_ids: query.sanitized_text }.merge(query.options[:params] || {})
      end
    end
  end
end
