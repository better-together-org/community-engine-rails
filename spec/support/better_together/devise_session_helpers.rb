# frozen_string_literal: true

module BetterTogether
  module DeviseSessionHelpers
    include FactoryBot::Syntax::Methods
    include Rails.application.routes.url_helpers
    include BetterTogether::Engine.routes.url_helpers

    def configure_host_platform
      platform = build(:better_together_platform)
      visit '/'
      fill_in 'platform[name]', with: platform.name
      fill_in 'platform[description]', with: platform.description
      select 'Public', from: 'Privacy'
      click_button 'Next Step'

      setup_admin_user
      BetterTogether::Platform.find_by(host: true)
    end

    def login_as_platform_manager
      visit new_user_session_url(locale: I18n.default_locale)
      fill_in 'user[email]', with: 'manager@example.test'
      fill_in 'user[password]', with: 'password12345'
      click_button 'Sign In'
    end

    def setup_admin_user
      person = build(:better_together_person)
      fill_in 'user[email]', with: 'manager@example.test'
      fill_in 'user[password]', with: 'password12345'
      fill_in 'user[password_confirmation]', with: 'password12345'
      fill_in 'user[person_attributes][name]', with: person.name
      fill_in 'user[person_attributes][identifier]', with: person.identifier
      fill_in 'user[person_attributes][description]', with: person.description
      click_button 'Finish Setup'

      platform_manager = BetterTogether::User.find_by(email: 'manager@example.test')
      platform_manager.confirm
    end

    def sign_in_user(email, password)
      visit new_user_session_url(locale: I18n.default_locale)
      fill_in 'user[email]', with: email
      fill_in 'user[password]', with: password
      click_button 'Sign In'
    end

    def sign_up_new_user(token, email, password, person)
      visit new_user_registration_path(invitation_code: token, locale: I18n.default_locale)
      fill_in 'user[email]', with: email
      fill_in 'user[password]', with: password
      fill_in 'user[password_confirmation]', with: password
      fill_in 'user[person_attributes][name]', with: person.name
      fill_in 'user[person_attributes][identifier]', with: person.identifier
      fill_in 'user[person_attributes][description]', with: person.description
      click_button 'Sign Up'

      created_user = BetterTogether::User.find_by(email: email)
      created_user.confirm
    end
  end
end
