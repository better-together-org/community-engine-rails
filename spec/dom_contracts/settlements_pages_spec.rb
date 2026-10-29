# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the settlement pages: the stable identifiers that documentation screenshots and
# downstream host-app overrides (e.g. Newfoundland Labrador Online's copies of these views) target.
# Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Settlement pages DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }

  describe 'settlements index' do
    before { get better_together.geography_settlements_path(locale:) }

    it 'exposes the heading gloss, the table and the new-settlement button' do # rubocop:disable RSpec/MultipleExpectations
      table = 'table#settlements-table[aria-describedby="settlements-description"]'

      expect(response).to have_http_status(:ok)
      expect(parsed_response.at_css('p#settlements-description')).to be_present
      expect(parsed_response.at_css(table)).to be_present
      expect(parsed_response.at_css('a#new-settlement-btn')).to be_present
    end
  end

  describe 'settlement row' do
    let!(:settlement) { create(:settlement) }

    it 'exposes a dom_id row inside the table' do
      get better_together.geography_settlements_path(locale:)

      row_id = ActionView::RecordIdentifier.dom_id(settlement)

      expect(parsed_response.at_css("table#settlements-table tr##{row_id}")).to be_present
    end
  end

  describe 'state page tabs' do
    let!(:state) { create(:state) }

    it 'keeps the tab id and its aria wiring stable' do # rubocop:disable RSpec/MultipleExpectations
      get better_together.geography_state_path(locale:, id: state.slug)

      tab = parsed_response.at_css('a#settlements-tab')
      expect(tab['aria-controls']).to eq('settlements')
      expect(parsed_response.at_css('div#settlements[aria-labelledby="settlements-tab"]')).to be_present
    end
  end
end
