# frozen_string_literal: true

module BetterTogether
  module SeedCatalog
    # Seed-catalog registry entry for GeographyBuilder — category-level granularity (Continents/
    # Countries/Provinces/Regions/Settlements), matching GeographyBuilder's own separable
    # seed_continents/seed_countries/etc. methods. First (and currently only) entry in the
    # seed-catalog framework — see BetterTogether::SeedCatalog::Registry for how another
    # builder's catalog would register alongside this one.
    class GeographyCatalog
      # `prerequisites:` matches GeographyBuilder's actual dependencies, not the display
      # ordering above it: seed_provinces looks up Country.find_by(identifier: 'canada') and
      # seed_settlements looks up State.find_by(...) then reads state.country - planting either
      # before its prerequisite exists raises NoMethodError on nil (nil.id / nil.country) with no
      # rescue anywhere in the call chain. continents/countries/regions have no such lookups.
      CATEGORIES = [
        { key: :continents, label: 'Continents', builder_method: :seed_continents,
          model: ::BetterTogether::Geography::Continent, prerequisites: [] },
        { key: :countries, label: 'Countries', builder_method: :seed_countries,
          model: ::BetterTogether::Geography::Country, prerequisites: [] },
        { key: :provinces, label: 'Provinces & Territories', builder_method: :seed_provinces,
          model: ::BetterTogether::Geography::State, prerequisites: [:countries] },
        { key: :regions, label: 'Regions', builder_method: :seed_regions,
          model: ::BetterTogether::Geography::Region, prerequisites: [] },
        { key: :settlements, label: 'Settlements', builder_method: :seed_settlements,
          model: ::BetterTogether::Geography::Settlement, prerequisites: [:provinces] }
      ].freeze

      class << self
        def key
          :geography
        end

        def label
          'Geography Reference Data'
        end

        def description
          'Continents, countries, provinces/territories, regions, and settlements used to ' \
            'place locations in the geography hierarchy.'
        end

        def categories
          CATEGORIES
        end

        def category(category_key)
          CATEGORIES.find { |entry| entry[:key] == category_key.to_s.to_sym }
        end

        # Coarse signal ("does at least one row exist"), not "is every seed-source entry
        # present" — a partially-interrupted plant would still show as planted. Acceptable for
        # an admin-triggered, re-runnable action; revisit if partial-plant tracking matters.
        def planted?(category_key)
          category(category_key)&.fetch(:model)&.exists? || false
        end

        # Prerequisite category keys not yet planted, in CATEGORIES' declared order. Empty when
        # category_key is unknown or already satisfied - callers that only care "can this be
        # planted right now" should check `.empty?` rather than presence/nil.
        def missing_prerequisites(category_key)
          entry = category(category_key)
          return [] unless entry

          Array(entry[:prerequisites]).reject { |prereq_key| planted?(prereq_key) }
        end

        # rubocop:todo Naming/PredicateMethod -- returns a success boolean, not a pure predicate
        def plant(category_key)
          entry = category(category_key)
          return false unless entry
          return true if planted?(category_key) # idempotent — a raw repeat POST bypasses the UI's disabled button
          return false if missing_prerequisites(category_key).any?

          without_auto_geocoding { ::BetterTogether::GeographyBuilder.public_send(entry[:builder_method]) }
          sync_dependent_joins!
          true
        end

        def plant_all
          without_auto_geocoding { ::BetterTogether::GeographyBuilder.build_if_missing }
          true
        end
        # rubocop:enable Naming/PredicateMethod

        private

        # Individual category planting only creates that category's own rows — the join tables
        # (country<->continent, region<->settlement) need both sides present first, and
        # GeographyBuilder's own seed_country_continents/seed_region_settlements are only called
        # as part of the full seed_data sequence. Planting categories one at a time through this
        # catalog otherwise leaves those cross-references empty even once both sides exist.
        def sync_dependent_joins!
          if planted?(:continents) && planted?(:countries) && ::BetterTogether::Geography::CountryContinent.none?
            ::BetterTogether::GeographyBuilder.seed_country_continents
          end

          return unless planted?(:regions) && planted?(:settlements) &&
                        ::BetterTogether::Geography::RegionSettlement.none?

          ::BetterTogether::GeographyBuilder.seed_region_settlements
        end

        # Geospatial::One's class_methods (an ActiveSupport::Concern block) mix into includers,
        # not into the concern module itself — must call through an actual includer. The
        # underlying suppression flag is a single thread-local shared across every includer, so
        # any of them works; Continent is as good as any.
        def without_auto_geocoding(&)
          ::BetterTogether::Geography::Continent.without_auto_geocoding(&)
        end
      end
    end
  end
end
