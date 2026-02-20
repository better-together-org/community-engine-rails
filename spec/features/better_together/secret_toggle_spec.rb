# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Secret Toggle Stimulus Controller', :as_platform_manager, :js, retry: 0 do
  let(:platform_manager_user) { BetterTogether::User.find_by!(email: 'manager@example.test') }

  before do
    configure_host_platform
    capybara_login_as_platform_manager
  end

  describe 'OAuth Application show page' do
    let!(:oauth_application) do
      create(:better_together_oauth_application,
             owner: platform_manager_user.person,
             confidential: true)
    end

    before do
      visit better_together.oauth_application_path(oauth_application, locale: I18n.default_locale)

      # Retry login if redirected to sign-in
      if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
        capybara_login_as_platform_manager
        visit better_together.oauth_application_path(oauth_application, locale: I18n.default_locale)
      end
    end

    it 'renders the secret field as a password input initially' do
      expect(page).to have_css('[data-controller="better-together--secret-toggle"]', wait: 10)

      field = find('[data-better-together--secret-toggle-target="field"]')
      expect(field['type']).to eq('password')
    end

    it 'toggles the secret field to text on first click' do
      expect(page).to have_css('[data-controller="better-together--secret-toggle"]', wait: 10)

      toggle_button = find('[data-action="better-together--secret-toggle#toggle"]')
      toggle_button.click

      field = find('[data-better-together--secret-toggle-target="field"]')
      expect(field['type']).to eq('text')
    end

    it 'toggles the icon from fa-eye to fa-eye-slash' do
      expect(page).to have_css('[data-controller="better-together--secret-toggle"]', wait: 10)

      # Before toggle: eye icon present, eye-slash absent
      expect(page).to have_css('[data-better-together--secret-toggle-target="icon"].fa-eye')
      expect(page).not_to have_css('[data-better-together--secret-toggle-target="icon"].fa-eye-slash')

      find('[data-action="better-together--secret-toggle#toggle"]').click

      # After toggle: eye-slash present, eye absent
      expect(page).to have_css('[data-better-together--secret-toggle-target="icon"].fa-eye-slash')
      expect(page).not_to have_css('[data-better-together--secret-toggle-target="icon"].fa-eye')
    end

    it 'toggles back to password on second click' do
      expect(page).to have_css('[data-controller="better-together--secret-toggle"]', wait: 10)

      toggle_button = find('[data-action="better-together--secret-toggle#toggle"]')
      toggle_button.click # reveal
      toggle_button.click # hide

      field = find('[data-better-together--secret-toggle-target="field"]')
      expect(field['type']).to eq('password')

      expect(page).to have_css('[data-better-together--secret-toggle-target="icon"].fa-eye')
      expect(page).not_to have_css('[data-better-together--secret-toggle-target="icon"].fa-eye-slash')
    end
  end

  describe 'Webhook Endpoint show page' do
    let!(:webhook_endpoint) do
      create(:better_together_webhook_endpoint,
             person: platform_manager_user.person)
    end

    before do
      visit better_together.webhook_endpoint_path(webhook_endpoint, locale: I18n.default_locale)

      # Retry login if redirected to sign-in
      if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
        capybara_login_as_platform_manager
        visit better_together.webhook_endpoint_path(webhook_endpoint, locale: I18n.default_locale)
      end
    end

    it 'renders the signing secret field as a password input initially' do
      expect(page).to have_css('[data-controller="better-together--secret-toggle"]', wait: 10)

      field = find('[data-better-together--secret-toggle-target="field"]')
      expect(field['type']).to eq('password')
    end

    it 'toggles the signing secret field to text on click' do
      expect(page).to have_css('[data-controller="better-together--secret-toggle"]', wait: 10)

      find('[data-action="better-together--secret-toggle#toggle"]').click

      field = find('[data-better-together--secret-toggle-target="field"]')
      expect(field['type']).to eq('text')

      icon = find('[data-better-together--secret-toggle-target="icon"]')
      expect(icon[:class]).to include('fa-eye-slash')
    end
  end
end
