# frozen_string_literal: true

module BetterTogether
  module SeedCatalog
    # Seed-catalog entry for the tax packets (config/seeds/better_together/billing/*.yml), planted on the host platform.
    # A category is a packet. Zones are tied to the geography rows, so a packet needs the geography it names planted
    # first (the countries and the provinces); that is its prerequisite, and it lives in the geography catalog.
    class BillingTaxCatalog
      CATEGORIES = [
        { key: :billing_tax_canada, label: 'Canadian sales tax', packet: 'billing_tax_canada',
          prerequisites: %i[countries provinces] }
      ].freeze

      class << self
        def key = :billing_tax

        def label = I18n.t('seed_catalog.billing_tax.label', default: 'Sales Tax Reference Data')

        def description
          I18n.t('seed_catalog.billing_tax.description',
                 default: 'Tax categories, zones and rates for the places a platform sells in. Zones are tied to the ' \
                          'geography provinces, so plant those first.')
        end

        def categories
          CATEGORIES.map do |entry|
            entry.merge(label: I18n.t("seed_catalog.billing_tax.categories.#{entry[:key]}", default: entry[:label]))
          end
        end

        # Prerequisites are geography categories, so a key this catalog does not hold is looked up there for its label.
        def category(category_key)
          key = category_key.to_s.to_sym
          categories.find { |entry| entry[:key] == key } || GeographyCatalog.category(key)
        end

        def planted?(category_key)
          entry = CATEGORIES.find { |candidate| candidate[:key] == category_key.to_s.to_sym }
          return false unless entry && platform

          Billing::Tax::Seeds::Planter.planted?(platform:, identifier: entry[:packet])
        rescue Billing::Tax::Seeds::Planter::Missing
          false
        end

        def missing_prerequisites(category_key)
          entry = CATEGORIES.find { |candidate| candidate[:key] == category_key.to_s.to_sym }
          return [] unless entry

          Array(entry[:prerequisites]).reject { |prerequisite| GeographyCatalog.planted?(prerequisite) }
        end

        # rubocop:disable Naming/PredicateMethod -- returns a success boolean, like the geography catalog
        def plant(category_key)
          entry = CATEGORIES.find { |candidate| candidate[:key] == category_key.to_s.to_sym }
          return false unless entry && platform
          return true if planted?(category_key)
          return false if missing_prerequisites(category_key).any?

          Billing::Tax::Seeds::Planter.call(platform:, identifier: entry[:packet])
          true
        end

        # Plants every packet whose prerequisites are in place.
        def plant_all
          CATEGORIES.each do |entry|
            plant(entry[:key])
          rescue Billing::Tax::Seeds::Planter::Missing => e
            Rails.logger.warn("Tax packet #{entry[:packet]} not planted: #{e.message}")
          end
          true
        end
        # rubocop:enable Naming/PredicateMethod

        private

        def platform = ::BetterTogether::Platform.find_by(host: true)
      end
    end
  end
end
