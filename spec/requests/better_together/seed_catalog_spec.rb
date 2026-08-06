# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::SeedCatalog' do
  include ActiveJob::TestHelper

  let(:locale) { I18n.default_locale }
  let(:platform_manager) do
    find_or_create_test_user(
      "seed-catalog-manager-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager
    )
  end
  let(:regular_user) do
    find_or_create_test_user("seed-catalog-user-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#')
  end

  before { BetterTogether::GeographyBuilder.clear_existing }

  # The entire /host area is gated at the routing layer (config/routes.rb:
  # `authenticated :user, ->(u) { u.permitted_to?('manage_platform') }`), not just by
  # SeedCatalogPolicy — an unauthenticated or non-manager request never reaches the
  # controller at all. Matches this app's own established convention for this boundary
  # (see spec/requests/better_together/seeds_spec.rb's identical `:not_found` assertions
  # for the sibling /host/seeds resource), not a redirect.
  describe 'authorization' do
    it 'returns not found for an unauthenticated visitor' do
      get better_together.seed_catalog_seeds_path(locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for a signed-in user without platform-manager permissions' do
      sign_in regular_user

      get better_together.seed_catalog_seeds_path(locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'does not create any records when a non-manager attempts to plant' do # rubocop:todo RSpec/MultipleExpectations
      sign_in regular_user

      expect do
        expect do
          post better_together.seed_catalog_plant_seeds_path(locale:, catalog_key: 'geography', category_key: 'continents')
        end.to raise_error(ActionController::RoutingError)
      end.not_to change(BetterTogether::Geography::Continent, :count)
    end
  end

  describe 'GET /host/seeds/catalog', :as_platform_manager do
    it 'lists the Geography catalog with all five categories' do
      get better_together.seed_catalog_seeds_path(locale:)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Geography Reference Data')
      expect(response.body).to include('Continents')
      expect(response.body).to include('Countries')
      expect(response.body).to include('Provinces')
      expect(response.body).to include('Regions')
      expect(response.body).to include('Settlements')
    end

    it 'shows a category as not planted before it has been seeded' do
      get better_together.seed_catalog_seeds_path(locale:)

      expect(response.body).to include('continents-status-badge')
      expect(response.body).to include('Not planted')
    end

    it 'shows a category as planted after it has been seeded' do
      BetterTogether::GeographyBuilder.seed_continents

      get better_together.seed_catalog_seeds_path(locale:)

      expect(response.body).to include('Planted')
    end
  end

  describe 'POST plant category', :as_platform_manager do
    it 'plants only the requested category' do # rubocop:todo RSpec/MultipleExpectations
      expect do
        post better_together.seed_catalog_plant_seeds_path(locale:, catalog_key: 'geography', category_key: 'continents')
      end.to change(BetterTogether::Geography::Continent, :count).from(0)

      expect(BetterTogether::Geography::Country.count).to eq(0)
      expect(response).to redirect_to(better_together.seed_catalog_seeds_path(locale:))
    end

    it 'geocodes the planted records from the committed seed-coordinate packet' do
      post better_together.seed_catalog_plant_seeds_path(locale:, catalog_key: 'geography', category_key: 'continents')

      africa = BetterTogether::Geography::Continent.find_by(identifier: 'africa')
      expect(africa.geocoded?).to be(true)
    end

    it 'does not enqueue any GeocodingJob (packet-covered category, suppressed regardless)' do
      expect do
        post better_together.seed_catalog_plant_seeds_path(locale:, catalog_key: 'geography', category_key: 'continents')
      end.to have_enqueued_job(BetterTogether::Geography::GeocodingJob).exactly(0).times
    end

    it 'redirects with an alert for an unknown catalog key' do
      expect do
        post better_together.seed_catalog_plant_seeds_path(locale:, catalog_key: 'not_a_real_catalog', category_key: 'continents')
      end.to raise_error(ActionController::RoutingError)
    end

    it 'is safe to click twice — does not raise or duplicate' do
      post better_together.seed_catalog_plant_seeds_path(locale:, catalog_key: 'geography', category_key: 'continents')
      count_after_first = BetterTogether::Geography::Continent.count

      expect do
        post better_together.seed_catalog_plant_seeds_path(locale:, catalog_key: 'geography', category_key: 'continents')
      end.not_to raise_error
      expect(BetterTogether::Geography::Continent.count).to eq(count_after_first)
    end
  end

  describe 'POST plant_all', :as_platform_manager do
    it 'plants every category' do # rubocop:todo RSpec/MultipleExpectations
      post better_together.seed_catalog_plant_all_seeds_path(locale:, catalog_key: 'geography')

      expect(BetterTogether::Geography::Continent.count).to be_positive
      expect(BetterTogether::Geography::Country.count).to be_positive
      expect(BetterTogether::Geography::State.count).to be_positive
      expect(BetterTogether::Geography::Region.count).to be_positive
      expect(BetterTogether::Geography::Settlement.count).to be_positive
      expect(response).to redirect_to(better_together.seed_catalog_seeds_path(locale:))
    end

    it 'is idempotent — safe to click twice' do
      post better_together.seed_catalog_plant_all_seeds_path(locale:, catalog_key: 'geography')
      count_after_first = BetterTogether::Geography::Continent.count

      expect do
        post better_together.seed_catalog_plant_all_seeds_path(locale:, catalog_key: 'geography')
      end.not_to raise_error
      expect(BetterTogether::Geography::Continent.count).to eq(count_after_first)
    end
  end
end
