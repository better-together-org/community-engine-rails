# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Geography::StatesController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/.../host/geography/states' do
    it 'renders index' do
      get better_together.geography_states_path(locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/.../host/geography/states/:id' do
    let!(:state) { create(:state) }

    it 'renders show' do
      get better_together.geography_state_path(locale:, id: state.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'renders the translated settlements tab' do
      get better_together.geography_state_path(locale:, id: state.slug)

      expect(parsed_response.at_css('a#settlements-tab').text)
        .to eq(I18n.t('better_together.geography.states.show.settlements_tab', locale:))
    end
  end
end
