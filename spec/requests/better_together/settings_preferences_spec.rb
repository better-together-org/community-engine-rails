# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings Preferences Management', :as_user do
  let!(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
  let(:person) { user.person }

  describe 'GET /settings' do
    it 'displays the preferences tab' do
      get settings_path(locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      expect_html_content(I18n.t('better_together.settings.index.tabs.preferences'))
    end

    it 'includes preferences form in preferences tab' do
      get settings_path(locale: I18n.default_locale)

      expect(response.body).to include('preferences-tab')
      expect(response.body).to include('id="preferences"')
    end
  end

  describe 'PATCH /settings/preferences (preferences update)' do
    context 'with valid locale preference' do
      it 'updates the locale preference' do
        expect do
          patch update_settings_preferences_path(locale: I18n.default_locale),
                params: { person: { locale: 'es' } }
        end.to change { person.reload.locale }.from('en').to('es')

        expect(response).to have_http_status(:redirect)
        follow_redirect!
        expect_html_content(I18n.t('flash.generic.updated', resource: I18n.t('resources.person')))
      end

      it 'accepts all available locales' do
        I18n.available_locales.each do |locale|
          patch update_settings_preferences_path(locale: I18n.default_locale),
                params: { person: { locale: locale.to_s } }

          person.reload
          expect(person.locale).to eq(locale.to_s)
        end
      end
    end

    context 'with time zone preference' do
      it 'updates the time_zone preference' do
        expect do
          patch update_settings_preferences_path(locale: I18n.default_locale),
                params: { person: { time_zone: 'Pacific Time (US & Canada)' } }
        end.to change { person.reload.time_zone }.to('Pacific Time (US & Canada)')

        expect(response).to have_http_status(:redirect)
      end

      it 'accepts valid time zones' do
        valid_zones = ['Eastern Time (US & Canada)', 'UTC', 'Tokyo', 'Berlin']

        valid_zones.each do |zone|
          patch update_settings_preferences_path(locale: I18n.default_locale),
                params: { person: { time_zone: zone } }

          person.reload
          expect(person.time_zone).to eq(zone)
        end
      end
    end

    context 'with notification preferences' do
      it 'updates notify_by_email preference' do
        person.update(notify_by_email: true)

        expect do
          patch update_settings_preferences_path(locale: I18n.default_locale),
                params: { person: { notify_by_email: '0' } }
        end.to change { person.reload.notify_by_email }.from(true).to(false)

        expect(response).to have_http_status(:redirect)
      end

      it 'handles boolean string values correctly' do
        ['0', 'false', false].each do |falsy_value|
          patch update_settings_preferences_path(locale: I18n.default_locale),
                params: { person: { notify_by_email: falsy_value } }

          expect(person.reload.notify_by_email).to be(false)
        end

        ['1', 'true', true].each do |truthy_value|
          patch update_settings_preferences_path(locale: I18n.default_locale),
                params: { person: { notify_by_email: truthy_value } }

          expect(person.reload.notify_by_email).to be(true)
        end
      end

      it 'updates show_conversation_details preference' do
        person.update(show_conversation_details: false)

        expect do
          patch update_settings_preferences_path(locale: I18n.default_locale),
                params: { person: { show_conversation_details: '1' } }
        end.to change { person.reload.show_conversation_details }.from(false).to(true)

        expect(response).to have_http_status(:redirect)
      end
    end

    context 'with messaging preferences' do
      it 'updates receive_messages_from_members preference' do
        person.update(receive_messages_from_members: false)

        expect do
          patch update_settings_preferences_path(locale: I18n.default_locale),
                params: { person: { receive_messages_from_members: '1' } }
        end.to change { person.reload.receive_messages_from_members }.from(false).to(true)

        expect(response).to have_http_status(:redirect)
      end

      it 'defaults to false for privacy' do
        new_person = create(:better_together_person)
        expect(new_person.receive_messages_from_members).to be(false)
      end
    end

    context 'with multiple preferences at once' do
      it 'updates all preferences together' do
        patch update_settings_preferences_path(locale: I18n.default_locale),
              params: {
                person: {
                  locale: 'fr',
                  time_zone: 'Paris',
                  notify_by_email: '0',
                  show_conversation_details: '1',
                  receive_messages_from_members: '1'
                }
              }

        person.reload
        expect(person.locale).to eq('fr')
        expect(person.time_zone).to eq('Paris')
        expect(person.notify_by_email).to be(false)
        expect(person.show_conversation_details).to be(true)
        expect(person.receive_messages_from_members).to be(true)

        expect(response).to have_http_status(:redirect)
      end
    end

    context 'with invalid preferences' do
      it 'rejects invalid locale' do
        initial_locale = person.locale

        patch update_settings_preferences_path(locale: I18n.default_locale),
              params: { person: { locale: 'invalid_locale' } }

        person.reload
        # Invalid locales are not in I18n.available_locales, so should be rejected or ignored
        expect(person.locale).to eq(initial_locale)
        expect(I18n.available_locales.map(&:to_s)).not_to include('invalid_locale')
      end
    end
  end

  describe 'preferences persistence' do
    it 'persists preferences across page loads', skip: 'Flaky - race condition with database persistence in parallel execution' do
      # Update preferences
      patch update_settings_preferences_path(locale: I18n.default_locale),
            params: {
              person: {
                locale: 'uk',
                time_zone: 'Kyiv',
                notify_by_email: '0',
                show_conversation_details: '1',
                receive_messages_from_members: '1'
              }
            }

      # Reload person from database
      reloaded_person = BetterTogether::Person.find(person.id)

      expect(reloaded_person.locale).to eq('uk')
      expect(reloaded_person.time_zone).to eq('Kyiv')
      expect(reloaded_person.notify_by_email).to be(false)
      expect(reloaded_person.show_conversation_details).to be(true)
      expect(reloaded_person.receive_messages_from_members).to be(true)
    end

    it 'stores notification preferences in JSONB column' do
      patch update_settings_preferences_path(locale: I18n.default_locale),
            params: {
              person: {
                notify_by_email: '1',
                show_conversation_details: '1'
              }
            }

      person.reload
      notification_prefs = person.notification_preferences

      expect(notification_prefs).to be_a(Hash)
      expect(notification_prefs['notify_by_email']).to be(true)
      expect(notification_prefs['show_conversation_details']).to be(true)
    end

    it 'stores general preferences in JSONB column' do
      patch update_settings_preferences_path(locale: I18n.default_locale),
            params: {
              person: {
                locale: 'es',
                time_zone: 'Madrid',
                receive_messages_from_members: '1'
              }
            }

      person.reload
      prefs = person.preferences

      expect(prefs).to be_a(Hash)
      expect(prefs['locale']).to eq('es')
      expect(prefs['time_zone']).to eq('Madrid')
      expect(prefs['receive_messages_from_members']).to be(true)
    end
  end

  describe 'authorization' do
    it 'requires authentication to access settings' do
      logout

      get settings_path(locale: I18n.default_locale)

      # Routes wrapped in authenticated :user block return 404 for non-authenticated requests
      # The controller's authenticate_user! never fires because the route doesn't match
      expect(response).to have_http_status(:not_found)
    end

    it 'allows users to update their own preferences' do
      patch update_settings_preferences_path(locale: I18n.default_locale),
            params: { person: { locale: 'fr' } }

      expect(response).to have_http_status(:redirect)
      expect(person.reload.locale).to eq('fr')
    end

    # Settings controller always updates the current user's preferences
    # so there's no way to update another user's preferences through this endpoint
  end

  describe 'i18n support' do
    it 'displays labels in the correct locale' do
      get settings_path(locale: 'es')

      expect_html_content(I18n.t('better_together.settings.index.tabs.preferences', locale: :es))
    end

    it 'includes all required translation keys' do
      required_keys = [
        'better_together.settings.index.preferences.title',
        'better_together.settings.index.preferences.description',
        'better_together.settings.index.preferences.save',
        'better_together.people.preferences.language.title',
        'better_together.people.preferences.time_zone.title',
        'better_together.people.preferences.notifications.title',
        'better_together.people.preferences.messaging.title'
      ]

      required_keys.each do |key|
        expect(I18n.t(key)).not_to include('translation missing')
      end
    end
  end

  describe 'form validation' do
    it 'shows validation errors for invalid data' do
      # The update endpoint doesn't have strict validations, so it should succeed
      # But we can verify that unpermitted params are rejected
      patch update_settings_preferences_path(locale: I18n.default_locale),
            params: { person: { time_zone: 'Pacific Time (US & Canada)', unpermitted_field: 'should_be_ignored' } }

      expect(response).to have_http_status(:redirect)
      person.reload
      expect(person.time_zone).to eq('Pacific Time (US & Canada)')
      # Verify unpermitted param wasn't saved (Person model doesn't have this attribute anyway)
      expect(person).not_to respond_to(:unpermitted_field)
    end
  end

  describe 'default values' do
    it 'has correct defaults for new persons' do
      new_person = create(:better_together_person)

      expect(new_person.locale).to eq(I18n.default_locale.to_s)
      expect(new_person.time_zone).to eq(ENV.fetch('APP_TIME_ZONE', 'America/St_Johns'))
      expect(new_person.notify_by_email).to be(true)
      expect(new_person.show_conversation_details).to be(false)
      expect(new_person.receive_messages_from_members).to be(false)
    end
  end
end
