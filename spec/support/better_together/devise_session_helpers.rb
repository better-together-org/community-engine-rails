# frozen_string_literal: true

module BetterTogether
  module CapybaraFeatureHelpers
    include FactoryBot::Syntax::Methods
    include Rails.application.routes.url_helpers
    include BetterTogether::Engine.routes.url_helpers

    # Setup or update a single host platform and return a platform_manager user
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def configure_host_platform
      # Reuse existing host platform if present, don't try to create a new one
      # Use find_or_create_by with rescue to handle race conditions in parallel tests
      host_platform = BetterTogether::Platform.find_by(host: true)
      unless host_platform
        begin
          host_community = BetterTogether::Community.find_or_create_by!(host: true) do |c|
            c.name = Faker::Company.unique.name
            c.description = Faker::Lorem.paragraph
            c.identifier = Faker::Internet.unique.username(specifier: 10..20)
            c.privacy = 'public'
            c.protected = true
          end

          host_platform = BetterTogether::Platform.find_or_create_by!(host: true) do |p|
            p.name = host_community.name
            p.description = host_community.description
            p.identifier = host_community.identifier
            p.host_url = "http://#{host_community.identifier}.test"
            p.time_zone = Faker::Address.time_zone
            p.privacy = 'public'
            p.protected = true
            p.community = host_community
          end
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
          if e.message.include?('Community host can only be set for one record') ||
             e.message.include?('Platform host can only be set for one record') ||
             e.message.include?('duplicate key')
            sleep(0.1)
            host_platform = BetterTogether::Platform.find_by(host: true)
            raise e unless host_platform
          else
            raise e
          end
        end
      end

      wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
      wizard.mark_completed

      platform_manager = BetterTogether::User.find_by(email: 'manager@example.test')

      unless platform_manager
        create(
          :user, :confirmed, :platform_manager,
          email: 'manager@example.test',
          password: 'SecureTest123!@#'
        )
      end

      host_platform
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def capybara_login_as_platform_manager
      capybara_sign_in_user('manager@example.test', 'SecureTest123!@#')
    end

    def capybara_login_as_user
      capybara_sign_in_user('user@example.test', 'SecureTest123!@#')
    end

    def capybara_sign_in_user(email, password)
      visit new_user_session_path(locale: I18n.default_locale)
      # If already authenticated, Devise may redirect to a dashboard. Only fill when fields exist.
      return unless page.has_field?('user[email]', disabled: false)

      fill_in 'user[email]', with: email
      fill_in 'user[password]', with: password
      click_button 'Sign In'
    end

    def capybara_sign_out_current_user
      click_on 'Log Out'
      Capybara.reset_session!
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

  # Alias for backward compatibility - some specs use this name
  DeviseSessionHelpers = CapybaraFeatureHelpers
end
