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

    def plant
      catalog = find_catalog!

      if catalog.plant(params[:category_key])
        redirect_to seed_catalog_seeds_path,
                    notice: t('seed_catalog.plant.success', category: params[:category_key].to_s.humanize)
      else
        redirect_to seed_catalog_seeds_path, alert: t('seed_catalog.plant.unknown_category')
      end
    end

    def plant_all
      catalog = find_catalog!
      catalog.plant_all

      redirect_to seed_catalog_seeds_path, notice: t('seed_catalog.plant_all.success', catalog: catalog.label)
    end

    private

    def authorize_seed_catalog
      authorize [:seed_catalog], :show?, policy_class: SeedCatalogPolicy
    end

    def find_catalog!
      BetterTogether::SeedCatalog::Registry.find(params[:catalog_key]) ||
        (raise ActionController::RoutingError, "Unknown seed catalog: #{params[:catalog_key]}")
    end
  end
end
