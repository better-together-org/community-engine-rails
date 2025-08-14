# frozen_string_literal: true

module BetterTogether
  module DeviseSessionHelpers
    include FactoryBot::Syntax::Methods
    include Rails.application.routes.url_helpers
    include BetterTogether::Engine.routes.url_helpers

    # Setup or update a single host platform and return a platform_manager user
    # rubocop:disable Metrics/MethodLength
    def configure_host_platform
      host_platform = BetterTogether::Platform.find_by(host: true)
      if host_platform
        host_platform.update!(privacy: 'public')
      else
        host_platform = create(:better_together_platform, :host, privacy: 'public')
      end

      wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
      wizard.mark_completed

      create(
        :user, :confirmed, :platform_manager,
        email: 'manager@example.test',
        password: 'password12345'
      )

      host_platform
    end
    # rubocop:enable Metrics/MethodLength

    def login_as_platform_manager
      sign_in_user('manager@example.test', 'password12345')
    end

    def sign_in_user(email, password)
      # Capybara.reset_session!
      visit new_user_session_path(locale: I18n.default_locale)
      fill_in 'user[email]', with: email
      fill_in 'user[password]', with: password
      click_button 'Sign In'
    end

    def sign_out_current_user
      click_on 'Log Out'
      Capybara.reset_session!
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
