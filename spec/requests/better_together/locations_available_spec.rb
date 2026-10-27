# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /locations/available' do
  # :as_platform_manager is scoped to just the contexts that need it (rather than
  # tagged on the top-level describe) for the same reason documented in
  # spec/requests/better_together/content/blocks_resource_search_spec.rb — a nested
  # :as_user/:no_auth context can't unset a truthy :as_platform_manager set higher up.
  context 'with a valid location_type', :as_platform_manager do
    it 'returns policy-scoped addresses' do
      address = create(:better_together_address, privacy: 'public')

      get better_together.available_locations_path(
        location_type: 'BetterTogether::Address',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first).to include('value', 'text')
      expect(json.map { |r| r['value'] }).to include(address.id)
    end

    it 'returns policy-scoped buildings' do
      building = create(:better_together_infrastructure_building, privacy: 'public')

      get better_together.available_locations_path(
        location_type: 'BetterTogether::Infrastructure::Building',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['value'] }).to include(building.id)
    end

    it 'returns unscoped settlements' do
      settlement = create(:geography_settlement)

      get better_together.available_locations_path(
        location_type: 'BetterTogether::Geography::Settlement',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['value'] }).to include(settlement.id)
    end

    it 'returns unscoped regions' do
      region = create(:geography_region)

      get better_together.available_locations_path(
        location_type: 'BetterTogether::Geography::Region',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['value'] }).to include(region.id)
    end

    it 'returns floors of policy-scoped buildings' do
      building = create(:better_together_infrastructure_building, privacy: 'public')
      floor = building.floors.first

      get better_together.available_locations_path(
        location_type: 'BetterTogether::Infrastructure::Floor',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['value'] }).to include(floor.id)
    end

    it 'returns rooms of policy-scoped buildings' do
      building = create(:better_together_infrastructure_building, privacy: 'public')
      room = building.rooms.first

      get better_together.available_locations_path(
        location_type: 'BetterTogether::Infrastructure::Room',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['value'] }).to include(room.id)
    end

    it 'filters settlements by the search param' do
      matching = create(:geography_settlement, name: 'Distinctive Settlement')
      other = create(:geography_settlement, name: 'Unrelated Place')

      get better_together.available_locations_path(
        location_type: 'BetterTogether::Geography::Settlement',
        search: 'Distinctive',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      values = json.map { |r| r['value'] }
      expect(values).to include(matching.id)
      expect(values).not_to include(other.id)
    end

    it 'filters addresses by the search param' do
      matching = create(:better_together_address, privacy: 'public', city_name: 'Searchtown')
      other = create(:better_together_address, privacy: 'public', city_name: 'Elsewhere')

      get better_together.available_locations_path(
        location_type: 'BetterTogether::Address',
        search: 'Searchtown',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      values = json.map { |r| r['value'] }
      expect(values).to include(matching.id)
      expect(values).not_to include(other.id)
    end
  end

  context 'with no location_type (mixed search)', :as_platform_manager do
    it 'returns composite ClassName:id values merged across every Placeable type' do
      address = create(:better_together_address, privacy: 'public', city_name: 'Mixed Search City')
      settlement = create(:geography_settlement, name: 'Mixed Search Settlement')

      get better_together.available_locations_path(
        search: 'Mixed Search',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      values = json.map { |r| r['value'] }
      expect(values).to include("#{address.class.name}:#{address.id}")
      expect(values).to include("#{settlement.class.name}:#{settlement.id}")
    end

    it 'excludes non-matching records from the merged result set' do
      create(:geography_settlement, name: 'Totally Unrelated Place')
      matching = create(:geography_settlement, name: 'Findable Settlement')

      get better_together.available_locations_path(
        search: 'Findable',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      values = json.map { |r| r['value'] }
      expect(values).to include("#{matching.class.name}:#{matching.id}")
      expect(values.size).to eq(1)
    end

    it 'appends the localized model name to each result\'s text' do
      settlement = create(:geography_settlement, name: 'Labeled Settlement')

      get better_together.available_locations_path(
        search: 'Labeled',
        locale: I18n.default_locale
      )

      json = JSON.parse(response.body)
      entry = json.find { |r| r['value'] == "#{settlement.class.name}:#{settlement.id}" }
      expect(entry['text']).to include(settlement.class.model_name.human)
    end
  end

  context 'with an invalid location_type', :as_platform_manager do
    it 'returns an error payload and unprocessable_content status' do
      get better_together.available_locations_path(
        location_type: 'NonExistentClass',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json).to eq({ 'error' => 'Invalid location type' })
    end

    it 'rejects a class that exists but is not Placeable' do
      get better_together.available_locations_path(
        location_type: 'BetterTogether::Person',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context 'with many matches', :as_platform_manager do
    it 'caps a single-type lookup and the per-type share of a mixed lookup', :aggregate_failures do
      country = create(:geography_country)
      state = create(:geography_state)
      create_list(:geography_settlement, BetterTogether::LocationsController::SINGLE_TYPE_RESULTS + 3, name: 'Capped Place',
                                                                                                       country:, state:)

      get better_together.available_locations_path(location_type: 'BetterTogether::Geography::Settlement',
                                                   search: 'Capped', locale: I18n.default_locale)
      expect(JSON.parse(response.body).size).to eq(BetterTogether::LocationsController::SINGLE_TYPE_RESULTS)

      get better_together.available_locations_path(search: 'Capped', locale: I18n.default_locale)
      expect(JSON.parse(response.body).size).to eq(BetterTogether::LocationsController::MIXED_RESULTS_PER_TYPE)
    end

    it 'accepts an oversized search term without error' do
      get better_together.available_locations_path(search: 'x' * 500, locale: I18n.default_locale)

      expect(response).to have_http_status(:ok)
    end
  end

  context 'when not authenticated', :no_auth do
    it 'does not serve the lookup', :aggregate_failures do
      get better_together.available_locations_path(location_type: 'BetterTogether::Address',
                                                   locale: I18n.default_locale)

      expect(response).not_to have_http_status(:ok)
      expect(response.body).not_to include('BetterTogether::Address')
    end
  end

  context 'when authenticated as a plain (non-manager) user', :as_user do
    it 'still returns the location list' do
      # Any signed-in person may search; privacy is applied by the available_<type>_for scopes.
      address = create(:better_together_address, privacy: 'public')

      get better_together.available_locations_path(
        location_type: 'BetterTogether::Address',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['value'] }).to include(address.id)
    end
  end
end
