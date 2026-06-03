# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SettingsController, :as_user do
  include Devise::Test::ControllerHelpers
  include BetterTogether::Engine.routes.url_helpers
  include AutomaticTestConfiguration

  render_views
  routes { BetterTogether::Engine.routes }

  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('settings-user@example.test', 'SecureTest123!@#', :user) }

  before { sign_in user }

  describe 'GET #my_data' do
    before do
      request.headers['Turbo-Frame'] = 'my-data-settings'
    end

    it 'renders export content without legacy seed or deletion sections' do
      create(:better_together_person_data_export, :completed, person: user.person)
      create(:better_together_seed, :personal_export, person: user.person)

      get :my_data, params: { locale: locale }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.exports.title'))
      expect(response.body).not_to include(I18n.t('better_together.settings.index.my_data.deletion.title'))
      expect(response.body).not_to include(I18n.t('better_together.settings.index.my_data.seeds.title'))
      expect(response.body).not_to include('fa-solid fa-database me-2')
    end
  end
end
