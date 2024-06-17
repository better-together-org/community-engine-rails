# frozen_string_literal: true

module BetterTogether
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController # rubocop:todo Style/Documentation
    # See https://github.com/omniauth/omniauth/wiki/FAQ#rails-session-is-clobbered-after-callback-on-developer-strategy
    skip_before_action :verify_authenticity_token, only: %i[github]

    before_action :set_person_platform_integration, except: [:failure]
    before_action :set_user, except: [:failure]

    attr_reader :person_platform_integration, :user

    def github
      handle_auth 'Github'
    end

    private

    def handle_auth(kind) # rubocop:todo Metrics/AbcSize
      if user.present?
        flash[:success] = t 'devise_omniauth_callbacks.success', kind: kind if is_navigational_format?
        sign_in_and_redirect user, event: :authentication
        redirect_to edit_user_registration_path
      else
        flash[:alert] =
          t 'devise_omniauth_callbacks.failure', kind:, reason: "#{auth.info.email} is not authorized"
        redirect_to new_user_registration_path
      end
    end

    def auth
      request.env['omniauth.auth']
    end

    def set_person_platform_integration
      @person_platform_integration = PersonPlatformIntegration.find_by(provider: auth.provider, uid: auth.uid)
    end

    def set_user
      @user = ::BetterTogether.user_class.from_omniauth(
        person_platform_integration:,
        auth:,
        current_user:
      )
    end

    def failure
      flash[:error] = 'There was a problem signing you in. Please register or try signing in later.'
      redirect_to helpers.base_url
    end
  end
end
