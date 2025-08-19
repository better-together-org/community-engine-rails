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

    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/PerceivedComplexity
    def sign_up_new_user(token, email, password, person) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      visit new_user_registration_path(invitation_code: token, locale: I18n.default_locale)
      fill_in 'user[email]', with: email
      fill_in 'user[password]', with: password
      fill_in 'user[password_confirmation]', with: password
      fill_in 'user[person_attributes][name]', with: person.name
      fill_in 'user[person_attributes][identifier]', with: person.identifier
      fill_in 'user[person_attributes][description]', with: person.description

      # Check agreement checkboxes. The view renders checkbox ids/names as
      # `terms_of_service_agreement` and `privacy_policy_agreement`. Older
      # specs sometimes reference `user_accept_terms_of_service` /
      # `user_accept_privacy_policy`, so try both.
      if page.has_unchecked_field?('terms_of_service_agreement')
        check 'terms_of_service_agreement'
      elsif page.has_unchecked_field?('user_accept_terms_of_service')
        check 'user_accept_terms_of_service'
      end

      if page.has_unchecked_field?('privacy_policy_agreement')
        check 'privacy_policy_agreement'
      elsif page.has_unchecked_field?('user_accept_privacy_policy')
        check 'user_accept_privacy_policy'
      end

      if page.has_unchecked_field?('code_of_conduct_agreement')
        check 'code_of_conduct_agreement'
      elsif page.has_unchecked_field?('user_accept_code_of_conduct')
        check 'user_accept_code_of_conduct'
      end

      click_button 'Sign Up'

      created_user = BetterTogether::User.find_by(email: email)
      created_user.confirm
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/MethodLength
  end
end
