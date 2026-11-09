# frozen_string_literal: true

module BetterTogether
  # Admin page listing registered seed catalogs (Geography today) and letting a platform manager
  # plant reference data on demand — one category at a time, or all at once — instead of it being
  # auto-seeded. See BetterTogether::SeedCatalog::Registry for the pluggable catalog list.
  class SeedCatalogController < ApplicationController
    before_action :authorize_seed_catalog

    def index
      @catalogs = BetterTogether::SeedCatalog::Registry.all
    end

    def plant # rubocop:todo Metrics/AbcSize
      catalog = find_catalog!
      category_key = params[:category_key]
      missing = catalog.missing_prerequisites(category_key)

      if missing.any?
        redirect_to seed_catalog_seeds_path,
                    alert: t('seed_catalog.plant.missing_prerequisites',
                             category: category_key.to_s.humanize,
                             prerequisites: missing.map { |key| key.to_s.humanize }.to_sentence)
      elsif plant_category(catalog, category_key)
        redirect_to seed_catalog_seeds_path,
                    notice: t('seed_catalog.plant.success', category: category_key.to_s.humanize)
      else
        redirect_to seed_catalog_seeds_path, alert: @planting_problem || t('seed_catalog.plant.unknown_category')
      end
    end

    def plant_all
      catalog = find_catalog!
      catalog.plant_all

      redirect_to seed_catalog_seeds_path, notice: t('seed_catalog.plant_all.success', catalog: catalog.label)
    end

    private

    # A tax packet names geography rows; one that is not there is said plainly instead of failing the page.
    def plant_category(catalog, category_key)
      catalog.plant(category_key)
    rescue BetterTogether::Billing::Tax::Seeds::Planter::Missing => e
      @planting_problem = e.message
      false
    end

    def authorize_seed_catalog
      authorize [:seed_catalog], :show?, policy_class: SeedCatalogPolicy
    end

    def find_catalog!
      BetterTogether::SeedCatalog::Registry.find(params[:catalog_key]) ||
        (raise ActionController::RoutingError, "Unknown seed catalog: #{params[:catalog_key]}")
    end
  end
end
