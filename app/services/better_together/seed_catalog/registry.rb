# frozen_string_literal: true

module BetterTogether
  module SeedCatalog
    # Registry of seed catalogs pluggable into the seed-catalog admin page. Geography and billing tax are
    # the registered catalogs today; add another builder's catalog by giving it the same class
    # interface as GeographyCatalog (.key, .label, .description, .categories, .planted?,
    # .plant, .plant_all) and registering it here — no controller/view/route changes needed.
    module Registry
      CATALOGS = {
        geography: BetterTogether::SeedCatalog::GeographyCatalog,
        billing_tax: BetterTogether::SeedCatalog::BillingTaxCatalog
      }.freeze

      def self.all
        CATALOGS.values
      end

      def self.find(key)
        CATALOGS[key.to_s.to_sym]
      end
    end
  end
end
