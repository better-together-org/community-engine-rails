# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /events/available_locations' do
  # :as_platform_manager is scoped to just the contexts that need it (rather than
  # tagged on the top-level describe) for the same reason documented in
  # spec/requests/better_together/content/blocks_resource_search_spec.rb — a nested
  # :as_user/:no_auth context can't unset a truthy :as_platform_manager set higher up.
  context 'with a valid location_type', :as_platform_manager do
    it 'returns policy-scoped addresses' do
      address = create(:better_together_address, privacy: 'public')

      get better_together.available_locations_events_path(
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

      get better_together.available_locations_events_path(
        location_type: 'BetterTogether::Infrastructure::Building',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['value'] }).to include(building.id)
    end

    it 'returns unscoped settlements' do
      settlement = create(:geography_settlement)

      get better_together.available_locations_events_path(
        location_type: 'BetterTogether::Geography::Settlement',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['value'] }).to include(settlement.id)
    end

    it 'returns unscoped regions' do
      region = create(:geography_region)

      get better_together.available_locations_events_path(
        location_type: 'BetterTogether::Geography::Region',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['value'] }).to include(region.id)
    end
  end

  context 'with an invalid location_type', :as_platform_manager do
    it 'returns an error payload and unprocessable_content status' do
      # Mirrors #available_hosts's own invalid-type convention (an {error:}
      # hash), not content/blocks#resource_search's `[]` convention — the two
      # endpoints diverge here and this spec follows the one this controller
      # action actually mirrors.
      get better_together.available_locations_events_path(
        location_type: 'NonExistentClass',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json).to eq({ 'error' => 'Invalid location type' })
    end

    it 'rejects a class that exists but is not Placeable' do
      get better_together.available_locations_events_path(
        location_type: 'BetterTogether::Person',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context 'when not authenticated', :no_auth do
    it 'returns 404' do
      # Verified pre-existing behavior, not something this new action
      # introduces: an unauthenticated request to *any* EventsController
      # collection route (confirmed identically on the untouched, older
      # #available_hosts action) never reaches the controller's own
      # `authorize` call at all. `EventsController#set_resource_instance`
      # (prepend_before_action, only: %i[show edit update destroy ics]) ends up
      # invoked with action_name == "show" for this request, and — finding no
      # event with id "available_locations" — falls through its
      # #handle_resource_not_found override to a 404, before Pundit's
      # NotAuthorizedError redirect path is ever reached. Root cause not
      # diagnosed (out of scope here, same category as the pre-existing 2025
      # location-selector flakiness this plan already excludes) — this spec
      # documents actual, verified behavior rather than the originally assumed
      # redirect.
      get better_together.available_locations_events_path(
        location_type: 'BetterTogether::Address',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when authenticated as a plain (non-manager) user', :as_user do
    it 'still returns the location list' do
      # #available_locations? mirrors #available_hosts?'s deliberately permissive
      # gate: `agent.valid_event_host_ids` always includes the person's own id
      # (Person#valid_event_host_ids prepends `[id]` unconditionally), so any
      # persisted, authenticated person passes — not just platform managers.
      # There is no "authenticated but not authorized" case for this gate.
      address = create(:better_together_address, privacy: 'public')

      get better_together.available_locations_events_path(
        location_type: 'BetterTogether::Address',
        locale: I18n.default_locale
      )

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |r| r['value'] }).to include(address.id)
    end
  end
end
