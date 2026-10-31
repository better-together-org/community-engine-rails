# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Geography::RegionsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/.../host/geography/regions' do
    it 'renders index' do
      get better_together.geography_regions_path(locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/.../host/geography/regions/:id' do
    let!(:region) { create(:region) }

    it 'renders show' do
      get better_together.geography_region_path(locale:, id: region.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'renders the translated settlements heading' do
      get better_together.geography_region_path(locale:, id: region.slug)

      expect_html_content(
        I18n.t('better_together.geography.regions.show.settlements_heading', name: region.name, locale:)
      )
    end
  end
end
