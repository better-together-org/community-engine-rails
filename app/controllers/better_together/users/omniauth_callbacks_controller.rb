# frozen_string_literal: true

module BetterTogether
  module Users
    class OmniauthCallbacksController < BetterTogether::OmniauthCallbacksController # rubocop:todo Style/Documentation
      include DeviseLocales

      skip_before_action :check_platform_privacy

      def self.omniauth_failure_handler
        proc do |env|
          env['devise.mapping'] = Devise.mappings[:user]
          action(:failure).call(env)
        end
      end

      def after_omniauth_failure_path_for(_scope)
        new_user_session_path(locale: I18n.locale)
      end

      def failure
        flash[:error] = t('devise_omniauth_callbacks.generic_failure')
        redirect_to after_omniauth_failure_path_for(:user), allow_other_host: false
      end
    end
  end
end
