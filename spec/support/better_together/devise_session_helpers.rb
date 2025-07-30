# frozen_string_literal: true

module BetterTogether
  module DeviseSessionHelpers
    include FactoryBot::Syntax::Methods
    include Rails.application.routes.url_helpers
    include BetterTogether::Engine.routes.url_helpers

    def configure_host_platform
      host_platform = create(:better_together_platform, :host, privacy: 'public')
      wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
      wizard.mark_completed
      host_platform
    end

    def login_as_platform_manager
      user = create(:user, :confirmed, :platform_manager)
      sign_in_user(user.email, user.password)
      user
    end

    def sign_in_user(email, password)
      # Capybara.reset_session!
      visit new_user_session_path(locale: I18n.default_locale)
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
