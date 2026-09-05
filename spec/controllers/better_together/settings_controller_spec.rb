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

    it 'renders export content and self-service connection links' do
      create(:better_together_person_data_export, :completed, person: user.person)
      create(:better_together_seed, :personal_export, person: user.person)

      get :my_data, params: { locale: locale }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.exports.title'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.connections.title'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.connections.cards.person_links.title'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.connections.cards.access_grants.title'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.connections.cards.linked_seeds.title'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.connections.cards.person_seeds.title'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.exports.status_values.completed'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.exports.table_caption'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.connections.cards.person_links.open_link'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.connections.cards.access_grants.open_link'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.connections.cards.linked_seeds.open_link'))
      expect(response.body).to include(I18n.t('better_together.settings.index.my_data.connections.cards.person_seeds.open_link'))
      expect(response.body).to include(person_links_path(locale: locale))
      expect(response.body).to include(person_access_grants_path(locale: locale))
      expect(response.body).to include(person_linked_seeds_path(locale: locale))
      expect(response.body).to include(person_seeds_path(locale: locale))
    end
  end
end
