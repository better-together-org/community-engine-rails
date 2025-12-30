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
      if user.present?
        # Complete user onboarding (community membership + invitations) FIRST
        complete_oauth_user_onboarding(user) if user.person.present?

        # THEN check for unaccepted required agreements after onboarding is complete
        if user.person.present? && user.person.unaccepted_required_agreements?
          # Store the user session but redirect to agreements page
          sign_in user
          store_location_for(:user, after_sign_in_path_for(user))
          flash[:alert] = t('better_together.agreements.status.acceptance_required')
          redirect_to better_together.agreements_status_path(locale: I18n.locale)
          return
        end

        flash[:success] = t 'devise_omniauth_callbacks.success', kind: kind if is_navigational_format?
        sign_in_and_redirect user, event: :authentication # This handles the redirect
      else
        flash[:alert] =
          t 'devise_omniauth_callbacks.failure', kind:, reason: "#{auth.info.email} is not authorized"
        redirect_to new_user_registration_path
      end
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

    def auth
      request.env['omniauth.auth']
    end

    def set_person_platform_integration
      @person_platform_integration = BetterTogether::PersonPlatformIntegration.find_by(provider: auth.provider,
                                                                                       uid: auth.uid)
    end

    def set_user
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
