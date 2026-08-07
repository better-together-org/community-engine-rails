# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the seed catalog: asserts the stable identifiers that documentation
# screenshots (spec/docs_screenshots/better_together/seed_catalog_spec.rb) and downstream
# tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Seed catalog DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  before { BetterTogether::GeographyBuilder.clear_existing }

  it 'exposes the stable identifiers the docs screenshots target' do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
    get "/#{I18n.default_locale}/host/seeds/catalog"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="seed-catalog"')
    expect(response.body).to include('id="seed-catalog-geography"')
    expect(response.body).to include('id="seed-catalog-geography-table"')
    expect(response.body).to include('id="seed-catalog-geography-continents-row"')
    expect(response.body).to include('class="continents-status-badge')
    expect(response.body).to include('id="plant-all-geography-btn"')
    expect(response.body).to include('id="plant-continents-btn"')
    expect(response.body).to include('id="plant-countries-btn"')
    expect(response.body).to include('id="plant-provinces-btn"')
    expect(response.body).to include('id="plant-regions-btn"')
    expect(response.body).to include('id="plant-settlements-btn"')
  end

  it 'reflects planted status in the badge once a category has records' do
    BetterTogether::SeedCatalog::GeographyCatalog.plant(:continents)

    get "/#{I18n.default_locale}/host/seeds/catalog"

    expect(response.body).to include('continents-status-badge badge bg-success')
  end

  it 'exposes the Seed Catalog link on the Host Dashboard' do
    get "/#{I18n.default_locale}/host"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="seed-catalog-link"')
  end
end
