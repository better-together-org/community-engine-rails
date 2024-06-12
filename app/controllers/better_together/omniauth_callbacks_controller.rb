# frozen_string_literal: true

module BetterTogether
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    # See https://github.com/omniauth/omniauth/wiki/FAQ#rails-session-is-clobbered-after-callback-on-developer-strategy
    skip_before_action :verify_authenticity_token, only: %i[github]

    def github
      @user = ::BetterTogether.user_class.from_omniauth(request.env['omniauth.auth'])
      if @user.persisted?
        sign_in_and_redirect @user
        set_flash_message(:notice, :success, kind: 'Github') if is_navigational_format?
      else
        flash[:error] = 'There was a problem signing you in through Github. Please register or try signing in later.'
        redirect_to new_user_registration_url
      end
    end

    def failure
      flash[:error] = 'There was a problem signing you in. Please register or try signing in later.'
      redirect_to helpers.base_url
    end
  end
end
