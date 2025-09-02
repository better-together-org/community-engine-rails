# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Geography::RegionSettlementsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/.../host/geography/region_settlements' do
    it 'renders index' do
      get better_together.geography_region_settlements_path(locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/.../host/geography/region_settlements/:id' do
    let!(:region_settlement) { create(:region_settlement) }

    it 'renders show' do
      get better_together.geography_region_settlement_path(locale:, id: region_settlement.id)
      expect(response).to have_http_status(:ok)
    end
  end
end
