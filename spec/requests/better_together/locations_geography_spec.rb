# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /locations/geography' do
  def lookup(**params)
    get better_together.geography_locations_path(locale: I18n.default_locale, **params)
    JSON.parse(response.body)
  end

  context 'when signed in', :as_user do
    let!(:canada) { create(:geography_country, name: 'Canada') }
    let!(:newfoundland) { create(:geography_state, country: canada, name: 'Newfoundland and Labrador') }
    let!(:ontario) { create(:geography_state, country: canada, name: 'Ontario') }
    let!(:other_state) { create(:geography_state, name: 'Elsewhere') }
    let!(:corner_brook) { create(:geography_settlement, country: canada, state: newfoundland, name: 'Corner Brook') }

    it 'lists countries' do
      expect(lookup(level: 'country').pluck('value')).to include(canada.id)
    end

    it 'narrows states to the chosen country' do
      values = lookup(level: 'state', country_id: canada.id).pluck('value')

      expect(values).to contain_exactly(newfoundland.id, ontario.id)
    end

    it 'narrows settlements to the chosen state' do
      expect(lookup(level: 'settlement', state_id: ontario.id)).to be_empty
    end

    it 'searches by name' do
      values = lookup(level: 'state', country_id: canada.id, search: 'newfound').pluck('value')

      expect(values).to eq([newfoundland.id])
    end

    it 'rejects an unknown level' do
      get better_together.geography_locations_path(locale: I18n.default_locale, level: 'planet')

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context 'when signed out', :no_auth do
    it 'does not answer' do
      get better_together.geography_locations_path(locale: I18n.default_locale, level: 'country')

      expect(response).not_to have_http_status(:ok)
    end
  end
end
