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

    it 'does not offer a new-settlement button while SettlementPolicy#create? is false' do
      get better_together.geography_settlements_path(locale:)

      expect(parsed_response.at_css('a#new-settlement-btn')).to be_nil
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

  describe 'settlement page tabs' do
    let!(:settlement) { create(:settlement) }

    before { get better_together.geography_settlement_path(locale:, id: settlement.slug) }

    it 'lazy-loads the posts index scoped to the settlement' do
      expect(parsed_response.at_css('turbo-frame#settlement-posts')['src'])
        .to include("settlement=#{settlement.identifier}")
    end

    it 'lazy-loads the events index scoped to the settlement' do
      expect(parsed_response.at_css('turbo-frame#settlement-events')['src'])
        .to include("settlement=#{settlement.identifier}")
    end

    it 'names the tab list for assistive technology' do
      expect(parsed_response.at_css('#geography-settlement[role="tablist"]')['aria-label'])
        .to eq(I18n.t('better_together.geography.settlements.show.sections_aria', locale:))
    end

    it 'omits the Communities tab when no community is located there' do
      expect(parsed_response.at_css('a#communities-tab')).to be_nil
    end
  end

  describe 'settlement page Communities tab' do
    let!(:settlement) { create(:settlement) }
    let!(:community) { create(:better_together_community, name: 'Harbour Guild', privacy: 'public') }

    before do
      create(:better_together_community, name: 'Hilltop Club', privacy: 'public')
      community.create_location!(location: settlement)
      get better_together.geography_settlement_path(locale:, id: settlement.slug)
    end

    it 'adds a Communities tab' do
      expect(parsed_response.at_css('a#communities-tab').text)
        .to eq(I18n.t('globals.tabs.communities', locale:))
    end

    it 'lists the communities located in the settlement' do
      expect_html_content('Harbour Guild')
    end

    it 'leaves out communities located elsewhere' do
      expect_no_html_content('Hilltop Club')
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
