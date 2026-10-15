# frozen_string_literal: true

module BetterTogether
  module Geography
    # Maintainer-only, local/offline generator: geocodes GeographyBuilder's static seed-source
    # data (continents/countries/provinces/regions/settlements) by name via live Nominatim and
    # writes the committed lib/better_together/geography/seed_coordinates.yml packet.
    #
    # This class is only ever invoked from the better_together:geography:generate_seed_coordinates
    # rake task — never at runtime, never at seed time, never in CI. GeographyBuilder only READS
    # this generator's committed output; it never calls this generator itself. Coordinates are
    # geocoded once, checked into source control, and reused indefinitely — the same reasoning
    # BoundaryImportJob already applies to boundary polygons, applied here to points instead.
    class SeedCoordinatesGenerator
      PACKET_PATH = BetterTogether::Engine.root.join('lib/better_together/geography/seed_coordinates.yml')
      CATEGORIES = %i[continents countries provinces regions settlements].freeze

      def self.call(force: false)
        new(force:).call
      end

      def initialize(force: false)
        @force = force
        @packet = force ? blank_packet : load_packet
      end

      def call
        with_live_nominatim_lookup do
          CATEGORIES.each { |category| geocode_category(category) }
        end

        write_packet
        summarize
      end

      private

      attr_reader :force, :packet

      def blank_packet
        CATEGORIES.to_h { |category| [category.to_s, {}] }
      end

      def load_packet
        return blank_packet unless File.exist?(PACKET_PATH)

        loaded = YAML.safe_load_file(PACKET_PATH) || {}
        blank_packet.merge(loaded) { |_key, defaults, existing| defaults.merge(existing || {}) }
      end

      def geocode_category(category)
        BetterTogether::GeographyBuilder.send(category).each { |entry| geocode_entry(category, entry) }
      end

      def geocode_entry(category, entry)
        identifier = entry[:name].parameterize
        return if !force && packet[category.to_s][identifier]

        coordinates = geocode(query_for(category, entry))
        return puts("  #{category}/#{identifier}: no geocode result, skipping") unless coordinates

        packet[category.to_s][identifier] = coordinates
        sleep 1.1
      end

      # Continents/countries geocode unambiguously by name alone. Provinces/regions/settlements
      # need a broader hint — every current seed-source province is Canadian (seed_provinces
      # hardcodes country_id to Canada), so "Canada" is a safe, non-arbitrary suffix rather than a
      # guess. Regions have no explicit province reference of their own in the source data (unlike
      # settlements' state_identifier) — current seed data is entirely Newfoundland and Labrador,
      # per every region's own description string, so that's hardcoded here; revisit if a
      # non-NL region is ever added to GeographyBuilder#regions.
      def query_for(category, entry)
        case category
        when :continents, :countries
          entry[:name]
        when :provinces
          "#{entry[:name]}, Canada"
        when :regions
          "#{entry[:name]}, Newfoundland and Labrador, Canada"
        when :settlements
          "#{entry[:name]}, #{province_name_for(entry[:state_identifier])}, Canada"
        end
      end

      def province_name_for(state_identifier)
        BetterTogether::GeographyBuilder.send(:provinces)
                                        .find { |province| province[:name].parameterize == state_identifier }
                                        &.fetch(:name)
      end

      def geocode(query)
        result = Geocoder.search(query).first
        return nil unless result

        { 'latitude' => result.latitude, 'longitude' => result.longitude }
      rescue StandardError => e
        Rails.logger.warn("SeedCoordinatesGenerator: failed to geocode #{query.inspect}: #{e.message}")
        nil
      end

      # Local dev/test environments default to Geocoder's :test lookup (canned stub responses —
      # see config/initializers/geocoder.rb), not real Nominatim. This generator's entire purpose
      # is producing real-world coordinates, so it force-overrides the lookup for its own duration
      # regardless of Rails.env, then restores whatever was configured before it ran.
      def with_live_nominatim_lookup
        previous = Geocoder.config.lookup
        Geocoder.configure(lookup: :nominatim)
        yield
      ensure
        Geocoder.configure(lookup: previous)
      end

      def write_packet
        FileUtils.mkdir_p(File.dirname(PACKET_PATH))
        File.write(PACKET_PATH, packet.to_yaml)
      end

      def summarize
        counts = packet.transform_values(&:size)
        puts "Seed coordinate packet written to #{PACKET_PATH}"
        counts.each { |category, count| puts "  #{category}: #{count} geocoded" }
        counts
      end
    end
  end
end
