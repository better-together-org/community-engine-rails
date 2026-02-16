# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth & Webhook Accessibility', :accessibility, :as_platform_manager, :js, retry: 0 do
  let(:platform_manager_user) { BetterTogether::User.find_by!(email: 'manager@example.test') }

  before do
    configure_host_platform
    capybara_login_as_platform_manager
  end

  shared_examples 'axe-clean page' do |description|
    it "#{description} passes WCAG 2.1 AA accessibility checks" do
      expect(page).to have_css('main, .container, .container-fluid', wait: 10)

      expect(page).to be_axe_clean
        .within('main')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end

  describe 'OAuth Applications' do
    let!(:oauth_application) do
      create(:better_together_oauth_application,
             owner: platform_manager_user.person,
             confidential: true)
    end

    describe 'index page' do
      before do
        visit better_together.oauth_applications_path(locale: I18n.default_locale)

        if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
          capybara_login_as_platform_manager
          visit better_together.oauth_applications_path(locale: I18n.default_locale)
        end
      end

      it_behaves_like 'axe-clean page', 'OAuth Applications index'
    end

    describe 'show page' do
      before do
        visit better_together.oauth_application_path(oauth_application, locale: I18n.default_locale)

        if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
          capybara_login_as_platform_manager
          visit better_together.oauth_application_path(oauth_application, locale: I18n.default_locale)
        end
      end

      it_behaves_like 'axe-clean page', 'OAuth Applications show'
    end

    describe 'new page' do
      before do
        visit better_together.new_oauth_application_path(locale: I18n.default_locale)

        if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
          capybara_login_as_platform_manager
          visit better_together.new_oauth_application_path(locale: I18n.default_locale)
        end
      end

      it_behaves_like 'axe-clean page', 'OAuth Applications new'
    end

    describe 'edit page' do
      before do
        visit better_together.edit_oauth_application_path(oauth_application, locale: I18n.default_locale)

        if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
          capybara_login_as_platform_manager
          visit better_together.edit_oauth_application_path(oauth_application, locale: I18n.default_locale)
        end
      end

      it_behaves_like 'axe-clean page', 'OAuth Applications edit'
    end
  end

  describe 'Webhook Endpoints' do
    let!(:webhook_endpoint) do
      create(:better_together_webhook_endpoint,
             person: platform_manager_user.person)
    end

    describe 'index page' do
      before do
        visit better_together.webhook_endpoints_path(locale: I18n.default_locale)

        if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
          capybara_login_as_platform_manager
          visit better_together.webhook_endpoints_path(locale: I18n.default_locale)
        end
      end

      it_behaves_like 'axe-clean page', 'Webhook Endpoints index'
    end

    describe 'show page' do
      before do
        visit better_together.webhook_endpoint_path(webhook_endpoint, locale: I18n.default_locale)

        if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
          capybara_login_as_platform_manager
          visit better_together.webhook_endpoint_path(webhook_endpoint, locale: I18n.default_locale)
        end
      end

      it_behaves_like 'axe-clean page', 'Webhook Endpoints show'
    end

    describe 'new page' do
      before do
        visit better_together.new_webhook_endpoint_path(locale: I18n.default_locale)

        if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
          capybara_login_as_platform_manager
          visit better_together.new_webhook_endpoint_path(locale: I18n.default_locale)
        end
      end

      it_behaves_like 'axe-clean page', 'Webhook Endpoints new'
    end

    describe 'edit page' do
      before do
        visit better_together.edit_webhook_endpoint_path(webhook_endpoint, locale: I18n.default_locale)

        if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
          capybara_login_as_platform_manager
          visit better_together.edit_webhook_endpoint_path(webhook_endpoint, locale: I18n.default_locale)
        end
      end

      it_behaves_like 'axe-clean page', 'Webhook Endpoints edit'
    end
  end
end
