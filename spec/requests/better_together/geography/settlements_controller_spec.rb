# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Geography::SettlementsController' do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  describe 'GET /:locale/.../host/geography/settlements' do
    it 'renders index' do
      get better_together.geography_settlements_path(locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/.../host/geography/settlements/:id' do
    let!(:settlement) { create(:settlement) }

    it 'renders show' do
      get better_together.geography_settlement_path(locale:, id: settlement.slug)
      expect(response).to have_http_status(:ok)
    end
  end
end
