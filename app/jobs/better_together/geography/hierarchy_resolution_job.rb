# frozen_string_literal: true

module BetterTogether
  module Geography
    # Resolves a geocoded locatable (Address/Building, or any model that includes
    # Geography::Locatable::Many and gets its own Space actually geocoded) to its
    # best-match containing geography hierarchy entities (Settlement/Region/State/
    # Country/Continent) via PostGIS polygon containment.
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

      # pg_trgm similarity() returns 0.0-1.0; 0.4 is a conservative-but-usable threshold
      # (Postgres's own pg_trgm.similarity_threshold GUC defaults to 0.3) chosen to favor
      # avoiding false positives over catching every minor spelling variant.
      STATE_NAME_SIMILARITY_THRESHOLD = 0.4

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

        resolved = resolve_by_polygon(locatable, point)
        resolve_country_by_iso_code(locatable, resolved)
        resolve_state_by_name_similarity(locatable, resolved)
      end

      private

      # Returns { level_symbol => matched_record }, only for levels with an actual match —
      # used both to skip already-resolved levels and to give the fallbacks below access to
      # the actual resolved Country/State records (not just a boolean), since the state
      # name-similarity fallback needs to scope its search to the resolved country.
      def resolve_by_polygon(locatable, point)
        resolved = {}

        BetterTogether::Geography::Locatable::Many::LEVELS.each do |level, klass|
          match = containing_record(klass, point)
          next unless match

          upsert_placement(locatable, level, match, 'polygon')
          resolved[level] = match
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
      # country_code nested under the 'address' sub-hash (matching Nominatim's actual
      # response shape — Geocoder::Result::Nominatim#country_code reads
      # @data['address']['country_code'], not a top-level key). Every Country is already
      # seeded and keyed by a globally-unique iso_code, so this is safe even when no
      # boundary polygon exists yet for that level.
      def resolve_country_by_iso_code(locatable, resolved)
        return if resolved[:country]

        country_code = locatable.space&.metadata&.dig('geocode', 'address', 'country_code')
        return if country_code.blank?

        country = BetterTogether::Geography::Country.find_by(iso_code: country_code.upcase)
        return unless country

        upsert_placement(locatable, :country, country, 'iso_code')
        resolved[:country] = country
      end

      # Fallback for State only, when no boundary polygon matched: Nominatim's "state" field
      # (aliased as state_code by the geocoder gem, but it is NOT a real ISO 3166-2
      # subdivision code — just the full state name, e.g. "Newfoundland and Labrador") is
      # fuzzy-matched via pg_trgm similarity() against every locale's translated State#name
      # (joined directly against mobility_string_translations, deliberately NOT scoped via
      # Mobility's `.i18n` query scope — `.i18n` scopes to Mobility.locale/I18n.locale *at
      # query time*, which for a background job is whatever the app's default locale is, not
      # the language Nominatim happened to respond in; matching across every locale's
      # translation and letting similarity() ranking pick the best one is more robust here).
      # Scoped to the already-resolved country (via polygon or iso_code) to avoid matching a
      # same/similar-named state in a different country.
      def resolve_state_by_name_similarity(locatable, resolved)
        return if resolved[:state] || resolved[:country].nil?

        state_name = locatable.space&.metadata&.dig('geocode', 'address', 'state')
        return if state_name.blank?

        match = state_name_similarity_scope(resolved[:country], state_name).first
        return unless match

        upsert_placement(locatable, :state, match, 'name_similarity')
        resolved[:state] = match
      end

      def state_name_similarity_scope(country, state_name)
        similarity = name_similarity_function(state_name)

        BetterTogether::Geography::State
          .where(country:)
          .joins(state_name_translations_join)
          .where(similarity.gt(STATE_NAME_SIMILARITY_THRESHOLD))
          .order(similarity.desc)
      end

      def name_similarity_function(name)
        translations = Arel::Table.new(:mobility_string_translations)
        Arel::Nodes::NamedFunction.new('similarity', [translations[:value], Arel::Nodes.build_quoted(name)])
      end

      def state_name_translations_join
        states = BetterTogether::Geography::State.arel_table
        translations = Arel::Table.new(:mobility_string_translations)

        states.join(translations)
              .on(translations[:translatable_type].eq('BetterTogether::Geography::State')
                    .and(translations[:translatable_id].eq(states[:id]))
                    .and(translations[:key].eq('name')))
              .join_sources
      end

      def upsert_placement(locatable, level, geography_record, method)
        location_type = BetterTogether::Geography::Locatable::Many::LEVELS.fetch(level).name
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
