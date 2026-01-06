# frozen_string_literal: true

module BetterTogether
  # Handles OAuth authentication callbacks from external providers (GitHub, Facebook, etc.).
  # Creates or updates PersonPlatformIntegration records and signs in users.
  # Enforces required agreement acceptance before allowing authenticated access.
  # rubocop:disable Metrics/ClassLength
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    include InvitationSessionManagement

    # CSRF protection handled by Rails authenticity token verification
    # OmniAuth CSRF disabled in config/initializers/devise.rb (proc {})
    # because button_to forms include Rails authenticity tokens

    # Allow already-signed-in users to connect OAuth accounts
    skip_before_action :authenticate_user!, raise: false

    before_action :set_person_platform_integration, except: [:failure]
    before_action :load_all_invitations_from_session, except: [:failure]
    before_action :check_invitation_requirement, except: [:failure]
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
      # If set_user before_action already redirected (e.g., due to ArgumentError), stop here
      return if performed?

      # Check if user is signed in (current_user is available in action method, not before_action)
      signed_in_user = current_user

      if user.present?
        # Complete user onboarding (community membership + invitations) FIRST
        complete_oauth_user_onboarding(user) if user.person.present?

        # Redirect based on agreements status and whether user is new/existing
        redirect_after_oauth(user, kind)
      elsif signed_in_user.present?
        # User was signed in but from_omniauth returned nil (integration failed to save)
        flash[:alert] = t('better_together.person_platform_integrations.create.failure',
                          provider: kind,
                          default: "Failed to connect #{kind} account. Please try again.")
        redirect_to better_together.settings_path(locale: I18n.locale, anchor: 'integrations'),
                    allow_other_host: false
      else
        reason = auth.present? ? "#{auth.info.email} is not authorized" : 'authentication failed'
        flash[:alert] = t('devise_omniauth_callbacks.failure', kind:, reason:)
        redirect_to new_user_registration_path
      end
    end

    # Redirect user after OAuth based on agreements status
    # @param user [User] the user to redirect
    # @param kind [String] OAuth provider name (e.g., 'Github')
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def redirect_after_oauth(user, kind)
      return unless user.present?

      if ENV['DEBUG_OAUTH']
        Rails.logger.debug "[OAUTH DEBUG] User: #{user.email}"
        Rails.logger.debug "[OAUTH DEBUG] Person present: #{user.person.present?}"
        Rails.logger.debug "[OAUTH DEBUG] Unaccepted agreements: #{user.person&.unaccepted_required_agreements?}"
        Rails.logger.debug "[OAUTH DEBUG] Existing user connecting: #{existing_user_connecting_oauth?}"
      end

      # Check for unaccepted required agreements
      if user.person.present? && user.person.unaccepted_required_agreements?
        Rails.logger.debug '[OAUTH DEBUG] Redirecting to agreements (has unaccepted)' if ENV['DEBUG_OAUTH']
        # User has unaccepted agreements - redirect to agreements page
        handle_unaccepted_agreements(user)
      elsif existing_user_connecting_oauth?
        Rails.logger.debug '[OAUTH DEBUG] Redirecting to settings (existing user connecting)' if ENV['DEBUG_OAUTH']
        # Determine success message based on context
        if is_navigational_format?
          flash[:success] = t('better_together.person_platform_integrations.create.success',
                              provider: kind)
        end
        # User already signed in - just redirect to settings integrations tab
        redirect_to better_together.settings_path(locale: I18n.locale, anchor: 'integrations'),
                    allow_other_host: false
      else
        Rails.logger.debug '[OAUTH DEBUG] New OAuth signup - signing in and redirecting' if ENV['DEBUG_OAUTH']
        # New OAuth signup - complete sign-in
        flash[:success] = t 'devise_omniauth_callbacks.success', kind: kind if is_navigational_format?
        sign_in user, event: :authentication
        redirect_to after_sign_in_path_for(user), allow_other_host: false
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Handle redirect when user has unaccepted agreements
    # @param user [User] the user with unaccepted agreements
    # rubocop:disable Metrics/AbcSize
    def handle_unaccepted_agreements(user)
      if existing_user_connecting_oauth?
        Rails.logger.debug '[OAUTH DEBUG] Existing user connecting - NOT signing in' if ENV['DEBUG_OAUTH']
        # Existing user connecting OAuth - don't auto-signin for security
        # They'll receive email notification about the new integration
      else
        Rails.logger.debug '[OAUTH DEBUG] New OAuth user - signing in before agreements' if ENV['DEBUG_OAUTH']
        # New OAuth user - sign them in and redirect to agreements
        sign_in user
        store_location_for(:user, after_sign_in_path_for(user))
      end
      flash[:alert] = t('better_together.agreements.status.acceptance_required')
      redirect_to better_together.agreements_status_path(locale: I18n.locale)
    end
    # rubocop:enable Metrics/AbcSize

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

    # Prevent OAuth signup when platform requires invitation
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def check_invitation_requirement
      return unless new_oauth_signup_attempt?
      return unless helpers.host_platform&.requires_invitation?
      return if valid_invitation_in_session?

      flash[:alert] = t('devise.omniauth_callbacks.invitation_required')
      redirect_to new_user_session_path(locale: I18n.locale),
                  allow_other_host: false
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    # Detect if this is a new user signup vs existing user OAuth connection
    # @return [Boolean] true if new signup, false if existing user or returning OAuth user
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def new_oauth_signup_attempt?
      return false if current_user.present? # Signed-in user connecting OAuth
      return false if person_platform_integration&.persisted? # Returning OAuth user with existing integration

      # Check if user exists by email
      email = auth&.dig('info', 'email')
      return false if email.blank?

      # If user is not signed in and trying to connect OAuth (whether new or existing email),
      # treat as new signup attempt requiring invitation validation
      true
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Check if there's a valid, unexpired invitation in the session
    # @return [Boolean] true if valid invitation exists
    def valid_invitation_in_session?
      @platform_invitation.present? ||
        @community_invitation.present? ||
        @event_invitation.present?
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
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def existing_user_connecting_oauth?
      if ENV['DEBUG_OAUTH']
        Rails.logger.debug "[OAUTH DEBUG] @was_signed_in: #{@was_signed_in}"
        Rails.logger.debug "[OAUTH DEBUG] @user_existed_before_oauth: #{@user_existed_before_oauth}"
        Rails.logger.debug "[OAUTH DEBUG] integration nil: #{person_platform_integration.nil?}"
        Rails.logger.debug "[OAUTH DEBUG] integration new_record: #{person_platform_integration&.new_record?}"
      end

      # User was already signed in before OAuth callback = connecting OAuth to existing account
      return true if @was_signed_in

      # User existed in database before OAuth callback AND wasn't signed in =
      # existing user who registered with email/password now connecting OAuth
      # Check if integration is nil (brand new) OR new_record (not yet saved)
      return true if @user_existed_before_oauth && !@was_signed_in &&
                     (person_platform_integration.nil? || person_platform_integration&.new_record?)

      # None of the above = either new OAuth signup OR returning OAuth sign-in
      false
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def auth
      request.env['omniauth.auth']
    end

    def set_person_platform_integration
      return unless auth.present?

      @person_platform_integration = BetterTogether::PersonPlatformIntegration.find_by(provider: auth.provider,
                                                                                       uid: auth.uid)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
    rescue ArgumentError => e
      # Handle OAuth validation errors (missing email, account already linked, etc.)
      @user = nil # Ensure user is nil so handle_auth doesn't process
      flash[:alert] = e.message

      # Redirect based on whether user is signed in or not
      redirect_path = if current_user.present?
                        better_together.settings_path(locale: I18n.locale, anchor: 'integrations')
                      else
                        new_user_registration_path
                      end

      redirect_to redirect_path, allow_other_host: false
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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
  # rubocop:enable Metrics/ClassLength
end
