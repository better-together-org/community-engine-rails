# frozen_string_literal: true

module BetterTogether
  # Handles OAuth authentication callbacks from external providers (GitHub, Facebook, etc.).
  # Creates or updates PersonPlatformIntegration records and signs in users.
  # Enforces required agreement acceptance before allowing authenticated access.
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    include InvitationSessionManagement

    # CSRF protection is handled by OmniAuth middleware configuration
    # See config/initializers/devise.rb for OmniAuth.config.request_validation_phase

    before_action :set_person_platform_integration, except: [:failure]
    before_action :load_all_invitations_from_session, except: [:failure]
    before_action :track_existing_user_state, except: [:failure]
    before_action :set_user, except: [:failure]

    attr_reader :person_platform_integration, :user

    # def facebook
    #   handle_auth "Facebook"
    # end

    def github
      handle_auth 'Github'
    end

    private

    # rubocop:todo Lint/CopDirectiveSyntax
    def handle_auth(kind) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Lint/CopDirectiveSyntax, Metrics/MethodLength
      # rubocop:enable Lint/CopDirectiveSyntax
      # Check if user is signed in (current_user is available in action method, not before_action)
      signed_in_user = current_user

      if user.blank? && signed_in_user.present?
        # User was signed in when OAuth started - use that user
        redirect_after_oauth(signed_in_user, kind)
        return
      end

      if user.present?
        # Complete user onboarding (community membership + invitations) FIRST
        complete_oauth_user_onboarding(user) if user.person.present?

        # Redirect based on agreements status and whether user is new/existing
        redirect_after_oauth(user, kind)
      else
        reason = auth.present? ? "#{auth.info.email} is not authorized" : 'authentication failed'
        flash[:alert] = t('devise_omniauth_callbacks.failure', kind:, reason:)
        redirect_to new_user_registration_path
      end
    end

    # Redirect user after OAuth based on agreements status
    # @param user [User] the user to redirect
    # @param kind [String] OAuth provider name (e.g., 'Github')
    def redirect_after_oauth(user, kind)
      return unless user.present?

      # Check for unaccepted required agreements
      if user.person.present? && user.person.unaccepted_required_agreements?
        # User has unaccepted agreements - redirect to agreements page
        handle_unaccepted_agreements(user)
      else
        # All agreements accepted - complete sign-in
        flash[:success] = t 'devise_omniauth_callbacks.success', kind: kind if is_navigational_format?

        # Sign in the user (this updates current_user) and then redirect
        sign_in user, event: :authentication
        redirect_to after_sign_in_path_for(user), allow_other_host: false
      end
    end

    # Handle redirect when user has unaccepted agreements
    # @param user [User] the user with unaccepted agreements
    def handle_unaccepted_agreements(user)
      if existing_user_connecting_oauth?
        # Existing user connecting OAuth - don't auto-signin for security
        # They'll receive email notification about the new integration
      else
        # New OAuth user - sign them in and redirect to agreements
        sign_in user
        store_location_for(:user, after_sign_in_path_for(user))
      end
      flash[:alert] = t('better_together.agreements.status.acceptance_required')
      redirect_to better_together.agreements_status_path(locale: I18n.locale)
    end

    # Complete onboarding for OAuth users (community membership + invitations)
    def complete_oauth_user_onboarding(user)
      # Ensure user has community membership
      ensure_community_membership(user)

      # Process any pending invitations (may update role/membership)
      handle_all_invitations(user)
    end

    # Ensure OAuth user has community membership
    # Mirrors setup_community_membership from RegistrationsController
    def ensure_community_membership(user)
      person = user.person
      return unless person.present?

      # Determine role from invitations if present
      community_role = determine_community_role_from_invitations

      helpers.host_community.person_community_memberships.find_or_create_by!(
        member: person
      ) do |membership|
        membership.role = community_role
        membership.status = 'active' # OAuth users skip confirmation, so membership is active immediately
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create community membership for OAuth user: #{e.message}"
      # Don't raise - allow sign-in to proceed even if membership creation fails
    end

    # Track if user existed before OAuth callback to determine signup vs connection
    def track_existing_user_state
      return unless auth.present?

      @was_signed_in = user_signed_in?
      @user_existed_before_oauth = ::BetterTogether.user_class.exists?(email: auth.dig('info', 'email'))
    end

    # Determines if this OAuth callback is for an existing user connecting a new account
    # vs a new user signing up via OAuth
    # @return [Boolean] true if existing user, false if new OAuth signup
    def existing_user_connecting_oauth?
      # User was already signed in before OAuth callback = connecting OAuth to existing account
      return true if @was_signed_in

      # Integration already existed before this callback = user reconnecting
      return true if person_platform_integration&.persisted? && person_platform_integration.user.present?

      # User existed in database before OAuth callback = existing user connecting OAuth
      return true if @user_existed_before_oauth

      # None of the above = new OAuth signup
      false
    end

    def auth
      request.env['omniauth.auth']
    end

    def set_person_platform_integration
      return unless auth.present?

      @person_platform_integration = BetterTogether::PersonPlatformIntegration.find_by(provider: auth.provider,
                                                                                       uid: auth.uid)
    end

    def set_user
      return unless auth.present?

      # Gather invitations from session to pass to from_omniauth
      invitations = {
        platform: @platform_invitation,
        community: @community_invitation,
        event: @event_invitation
      }.compact

      @user = ::BetterTogether.user_class.from_omniauth(
        person_platform_integration:,
        auth:,
        current_user:,
        invitations:
      )
    end

    # def github
    #   @user = ::BetterTogether.user_class.from_omniauth(request.env['omniauth.auth'])
    #   if @user.persisted?
    #     sign_in_and_redirect @user
    #     set_flash_message(:notice, :success, kind: 'Github') if is_navigational_format?
    #   else
    #     flash[:error] = 'There was a problem signing you in through Github. Please register or try signing in later.'
    #     redirect_to new_user_registration_url
    #   end
    # end

    def failure
      flash[:error] = 'There was a problem signing you in. Please register or try signing in later.'
      redirect_to helpers.base_url
    end
  end
end
