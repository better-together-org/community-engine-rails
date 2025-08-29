# frozen_string_literal: true

module BetterTogether
  module CapybaraFeatureHelpers
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

      platform_manager = BetterTogether::User.find_by(email: 'manager@example.test')

      unless platform_manager
        create(
          :user, :confirmed, :platform_manager,
          email: 'manager@example.test',
          password: 'password12345'
        )
      end

      host_platform
    end
    # rubocop:enable Metrics/MethodLength

    def capybara_login_as_platform_manager
      capybara_sign_in_user('manager@example.test', 'password12345')
    end

    def capybara_login_as_user
      capybara_sign_in_user('user@example.test', 'password12345')
    end

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    def capybara_sign_in_user(email, password) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      # If we've already signed in this user in the current session, skip re-authentication.
      if defined?(@capybara_signed_in_user_email) && @capybara_signed_in_user_email == email && (page.has_selector?('#user-nav') || page.has_link?('Log Out') || page.has_content?(email)) # rubocop:disable Layout/LineLength
        # double-check UI shows a signed-in user to avoid stale memo
        return
      end

      # If some other user is signed in, sign them out first so we can sign in as the requested user.
      if page.has_selector?('#user-nav') && !page.has_content?(email)
        begin
          capybara_sign_out_current_user
        rescue StandardError
          # ignore sign-out failures and continue to sign-in flow
        end
      end

      # If the login fields are already present on the current page, use them instead of navigating.
      if page.has_field?('user[email]', disabled: false)
        # Proceed to fill the existing login form
      else
        visit new_user_session_path(locale: I18n.default_locale)
      end

      # If already authenticated Devise may redirect to a dashboard; only fill when fields exist.
      return unless page.has_field?('user[email]', disabled: false)

      fill_in 'user[email]', with: email
      fill_in 'user[password]', with: password
      click_button 'Sign In'

      # Memoize the signed-in email to avoid repeating sign-in steps in the same Capybara session
      @capybara_signed_in_user_email = email
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    def capybara_sign_out_current_user
      # Attempt to click 'Log Out' only if present; always reset session afterwards and clear memo
      click_on 'Log Out' if page.has_link?('Log Out') || page.has_button?('Log Out') || page.has_selector?('#user-nav')
      Capybara.reset_session!
      @capybara_signed_in_user_email = nil
    end

    # Legacy method names for backward compatibility
    alias login_as_platform_manager capybara_login_as_platform_manager
    alias sign_in_user capybara_sign_in_user
    alias sign_out_current_user capybara_sign_out_current_user

    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/CyclomaticComplexity
    def sign_up_new_user(token, email, password, person) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      visit new_user_registration_path(invitation_code: token, locale: I18n.default_locale)
      # Some invitation flows prefill and disable the email field
      fill_in 'user[email]', with: email if page.has_field?('user[email]', disabled: false)
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
    # rubocop:enable Metrics/CyclomaticComplexity
  end
end
