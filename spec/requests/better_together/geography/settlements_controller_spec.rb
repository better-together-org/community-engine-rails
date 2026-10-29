# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Geography::SettlementsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/.../host/geography/settlements' do
    it 'renders index' do
      get better_together.geography_settlements_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'explains what a settlement is, beneath the heading' do
      get better_together.geography_settlements_path(locale:)

      expect_html_content(I18n.t('better_together.geography.settlements.index.description', locale:))
    end

    it 'links the gloss to the table for assistive technology' do
      get better_together.geography_settlements_path(locale:)

      expect(parsed_response.at_css('#settlements-table')['aria-describedby']).to eq('settlements-description')
    end

    it 'exposes a stable id on the new-settlement button' do
      get better_together.geography_settlements_path(locale:)

      expect(parsed_response.at_css('a#new-settlement-btn')).to be_present
    end

    %i[es fr uk].each do |other_locale|
      it "renders the #{other_locale} label and gloss instead of the English ones" do
        get better_together.geography_settlements_path(locale: other_locale)

        expect_html_contents(
          I18n.t('better_together.geography.settlements.index.title', locale: other_locale),
          I18n.t('better_together.geography.settlements.index.description', locale: other_locale)
        )
      end
    end
  end

  describe 'GET /:locale/.../host/geography/settlements/:id' do
    let!(:settlement) { create(:settlement) }

    it 'renders show' do
      get better_together.geography_settlement_path(locale:, id: settlement.slug)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/.../host/geography/settlements/:id/edit' do
    let!(:settlement) { create(:settlement) }

    it 'renders edit' do
      get better_together.edit_geography_settlement_path(locale:, id: settlement.slug)
      expect(response).to have_http_status(:ok)
    end
  end
end
