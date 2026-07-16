# frozen_string_literal: true

module BetterTogether
  module Geography
    # Resolves a geocoded locatable (Address/Building/Event, or any model that includes
    # Geography::Locatable::Many) to its best-match containing geography hierarchy entities
    # (Settlement/Region/State/Country/Continent) via PostGIS polygon containment.
    #
    # Each level is resolved independently against its own Space#boundary — there is no
    # assumption that a settlement's polygon nests inside its region's polygon. Given the
    # curated hierarchy is deliberately sparse, most levels will simply have no matching
    # LocatableLocation row; that is expected, not an error. This job never creates new
    # Settlement/Region/State/Country/Continent records.
    class HierarchyResolutionJob < ApplicationJob
      queue_as :geocoding
      retry_on StandardError, wait: :polynomially_longer, attempts: 5
      discard_on ActiveJob::DeserializationError

      LEVELS = %i[settlement region state country continent].freeze

      # Orchestrates a full backfill run for `better_together:geography:backfill_placements`
      # — iterates Locatable::Many.included_in_models dynamically (not a hardcoded
      # [Address, Building, Event] list), so a new model opts in with just one `include`
      # line. Enqueues async (perform_later) rather than running inline: unlike
      # BoundaryImportJob, containment queries are cheap local DB reads, not
      # rate-limited external calls, so it's safe to fan out across the whole queue.
      #
      # "Already resolved" is approximated as "has at least one resolved LocatableLocation
      # row" — a record whose geocoded point matches nothing at any level (no boundary
      # anywhere, no usable country_code) would have zero rows and re-enqueue on every
      # backfill run. That's accepted: re-running containment queries is cheap, and this
      # keeps the skip-check simple rather than needing a separate "attempted but empty"
      # marker on each locatable.
      def self.backfill_all_missing
        enqueued = 0

        BetterTogether::Geography::Locatable::Many.included_in_models.each do |klass|
          next unless klass.reflect_on_association(:space)

          klass.joins(:space).merge(BetterTogether::Geography::Space.geocoded).find_each do |record|
            next if record.locatable_locations.where.not(resolved_at: nil).exists?

            perform_later(record)
            enqueued += 1
          end
        end

        { enqueued: }
      end

      def perform(locatable)
        return unless locatable.respond_to?(:space)

        point = locatable.space&.to_rgeo_point
        return if point.nil?

        resolved_levels = resolve_by_polygon(locatable, point)
        resolve_by_iso_code_fallback(locatable, resolved_levels)
      end

      private

      def resolve_by_polygon(locatable, point)
        resolved = {}

        LEVELS.each do |level|
          klass = "BetterTogether::Geography::#{level.to_s.camelize}".constantize
          match = containing_record(klass, point)
          next unless match

          upsert_placement(locatable, level, match, 'polygon')
          resolved[level] = true
        end

        resolved
      end

      # ST_Covers (not ST_Contains) — PostGIS's `geography` type has no ST_Contains overload
      # at all (ST_Contains is geometry-only); ST_Covers is the geography-aware,
      # GiST-index-usable equivalent. It includes boundary-edge points (unlike strict
      # ST_Contains), which is the accepted approximation for coastal/border settlements.
      #
      # Built via rgeo-activerecord's Arel spatial-expression DSL (arel_table[:col].st_*),
      # not a raw SQL string: st_contains/st_within/etc. don't include st_covers as a named
      # convenience method, but st_function(name, *args, flags) is the documented escape
      # hatch for any PostGIS function — it still produces a proper SpatialNamedFunction
      # Arel node. The [false, true, true] flags (result/lhs/rhs "is spatial") match the
      # gem's own st_contains/st_within definitions; marking the point argument as spatial is
      # what makes the visitor wrap it in `ST_GeomFromText(wkt, srid)` (auto-cast to
      # `geography` for the ST_Covers(geography, geography) overload) instead of raising
      # PG::UndefinedFunction on an untyped bind parameter, which a bare `?` in a raw SQL
      # string does not do.
      def containing_record(klass, point)
        space_table = BetterTogether::Geography::Space.arel_table

        klass.joins(:space)
             .where(space_table[:boundary].not_eq(nil))
             .where(space_table[:boundary].st_function('ST_Covers', point, [false, true, true]))
             .first
      end

      # Cross-check/fallback for Country only: Geocoder's raw result (persisted onto
      # space.metadata['geocode'] by GeocodingJob) carries a real ISO 3166-1 alpha-2
      # country_code, and every Country is already seeded and keyed by a globally-unique
      # iso_code, so this is safe even when no boundary polygon exists yet for that level.
      #
      # NOTE: Nominatim's "state_code" is NOT a real ISO 3166-2 subdivision code — the
      # geocoder gem simply aliases it to the full state *name* (e.g. "Newfoundland and
      # Labrador", not "NL"). There is no reliable code-based State fallback available from
      # geocoding data; State resolution relies on polygon containment only, once boundary
      # data has been imported for it.
      def resolve_by_iso_code_fallback(locatable, resolved_levels)
        return if resolved_levels[:country]

        country_code = locatable.space&.metadata&.dig('geocode', 'country_code')
        return if country_code.blank?

        country = BetterTogether::Geography::Country.find_by(iso_code: country_code.upcase)
        upsert_placement(locatable, :country, country, 'iso_code') if country
      end

      def upsert_placement(locatable, level, geography_record, method)
        location_type = "BetterTogether::Geography::#{level.to_s.camelize}"
        placement = BetterTogether::Geography::LocatableLocation.find_or_initialize_by(
          locatable:, location_type:
        )
        placement.location = geography_record
        placement.resolution_method = method
        placement.resolved_at = Time.current
        placement.save!
      end
    end
  end
end
