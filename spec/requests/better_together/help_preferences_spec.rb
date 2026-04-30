# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::HelpPreferencesController', :as_user do
  let(:locale) { I18n.default_locale }
  let(:person) { BetterTogether::User.find_by(email: 'user@example.test')&.person }
  let(:banner_id) { 'host-dashboard' }

  describe 'POST /:locale/help_banners/hide' do
    it 'raises a routing error when unauthenticated because the route is constrained' do
      logout

      expect do
        post better_together.hide_help_banner_path(locale:, id: banner_id)
      end.to raise_error(ActionController::RoutingError)
    end

    it 'stores a hidden help-banner preference and redirects for html requests' do
      post better_together.hide_help_banner_path(locale:, id: banner_id)

      expect(response).to have_http_status(:found)
      expect(person.reload.preferences.dig('help_banners', banner_id, 'hidden')).to be(true)
      expect(person.preferences.dig('help_banners', banner_id, 'locale')).to eq(locale.to_s)
      expect(person.preferences.dig('help_banners', banner_id, 'updated_at')).to be_present
    end

    it 'returns ok for json requests while storing the hidden preference' do
      post better_together.hide_help_banner_path(locale:, id: banner_id), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.body).to be_blank
      expect(person.reload.preferences.dig('help_banners', banner_id, 'hidden')).to be(true)
    end
  end

  describe 'POST /:locale/help_banners/show' do
    before do
      person.update!(preferences: {
                       'help_banners' => {
                         banner_id => { 'hidden' => true, 'locale' => locale.to_s, 'updated_at' => 1.minute.ago }
                       }
                     })
    end

    it 'marks the help banner as visible again' do
      post better_together.show_help_banner_path(locale:, id: banner_id), as: :json

      expect(response).to have_http_status(:ok)
      expect(person.reload.preferences.dig('help_banners', banner_id, 'hidden')).to be(false)
      expect(person.preferences.dig('help_banners', banner_id, 'locale')).to eq(locale.to_s)
      expect(person.preferences.dig('help_banners', banner_id, 'updated_at')).to be_present
    end
  end
end
