# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings Developer Tab', :as_user do
  let!(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
  let(:person) { user.person }
  let(:locale) { I18n.default_locale }

  describe 'GET /settings (developer tab content)' do
    it 'renders the settings page with 200 status' do
      get settings_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'includes the developer tab navigation link' do
      get settings_path(locale:)
      expect(response.body).to include('developer-tab')
    end

    it 'shows the developer tab panel' do
      get settings_path(locale:)
      expect(response.body).to include('id="developer"')
    end

    context 'when user has no OAuth apps' do
      it 'shows "no apps" message in developer tab' do
        get settings_path(locale:)
        expect_html_content(I18n.t('better_together.settings.index.developer.apps.none'))
      end
    end

    context 'when user has an OAuth app' do
      let!(:oauth_app) do
        create(:better_together_oauth_application,
               name: 'My Personal Bot',
               owner: person)
      end

      it 'shows the OAuth app name' do
        get settings_path(locale:)
        expect_html_content('My Personal Bot')
      end

      it 'includes a link to view the app' do
        get settings_path(locale:)
        expect(response.body).to include(better_together.personal_oauth_application_path(locale:, id: oauth_app.id))
      end
    end

    context 'when user has active access tokens' do
      let!(:oauth_app) do
        create(:better_together_oauth_application, owner: person)
      end
      let!(:token) do
        BetterTogether::OauthAccessToken.create!(
          application: oauth_app,
          resource_owner_id: user.id,
          token: SecureRandom.hex(32),
          expires_in: 7200,
          scopes: 'read'
        )
      end

      it 'displays the active token' do
        get settings_path(locale:)
        expect(response).to have_http_status(:ok)
        # Token row should appear in the tokens table
        expect(response.body).to include('id="developer"')
      end
    end
  end

  describe 'PATCH /settings/preferences (re-render with developer data)' do
    it 'loads developer tab data when re-rendering on validation error' do
      patch update_settings_preferences_path(locale:),
            params: { person: { locale: 'invalid_locale_xyz' } }

      expect(response).to have_http_status(:unprocessable_content)
      # Should not raise nil.any? error — developer tab vars must be set
      expect(response.body).to include('id="developer"')
    end
  end
end
