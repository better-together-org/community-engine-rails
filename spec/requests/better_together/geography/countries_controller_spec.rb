# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Geography::CountriesController' do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  describe 'GET /:locale/.../host/geography/countries' do
    it 'renders index' do
      get better_together.geography_countries_path(locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/.../host/geography/countries/:id' do
    let!(:country) { create(:geography_country) }

    it 'renders show' do
      get better_together.geography_country_path(locale:, id: country.slug)
      expect(response).to have_http_status(:ok)
    end
  end
end
