# frozen_string_literal: true

module BetterTogether
  module SeedCatalog
    # Seed-catalog entry for the purchase agreements (config/seeds/better_together/billing_agreements/*.yml), planted on the
    # host platform: draft subscription, one-time purchase and offline payment agreements with placeholder text, tied to the
    # purchases they cover. They need no other reference data; nothing can be sold until a steward writes the terms and
    # activates them.
    class BillingAgreementsCatalog
      CATEGORIES = [
        { key: :billing_purchase_agreements, label: 'Purchase agreements', prerequisites: [] }
      ].freeze

      class << self
        def key = :billing_agreements

        def label = I18n.t('seed_catalog.billing_agreements.label', default: 'Billing Agreements')

        def description
          I18n.t('seed_catalog.billing_agreements.description',
                 default: 'Draft purchase agreements with placeholder text. Nothing can be sold until a steward writes the ' \
                          'terms and activates them.')
        end

        def categories
          CATEGORIES.map do |entry|
            entry.merge(label: I18n.t("seed_catalog.billing_agreements.categories.#{entry[:key]}", default: entry[:label]))
          end
        end

        def category(category_key)
          categories.find { |entry| entry[:key] == category_key.to_s.to_sym }
        end

        def planted?(category_key)
          return false unless known?(category_key) && platform

          Billing::PurchaseAgreementSeeds.planted?(platform)
        end

        def missing_prerequisites(_category_key) = []

        # rubocop:disable Naming/PredicateMethod -- returns a success boolean, like the other catalogs
        def plant(category_key)
          return false unless known?(category_key) && platform
          return true if planted?(category_key)

          Billing::PurchaseAgreementSeeds.call(platform)
          true
        end

        def plant_all
          CATEGORIES.each { |entry| plant(entry[:key]) }
          true
        end
        # rubocop:enable Naming/PredicateMethod

        private

        def known?(category_key) = CATEGORIES.any? { |entry| entry[:key] == category_key.to_s.to_sym }

        def platform = ::BetterTogether::Platform.find_by(host: true)
      end
    end
  end
end
