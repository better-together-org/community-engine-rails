# frozen_string_literal: true

module BetterTogether
  module Users
    class OmniauthCallbacksController < BetterTogether::OmniauthCallbacksController # rubocop:todo Style/Documentation
      include DeviseLocales

      skip_before_action :check_platform_privacy

      def after_omniauth_failure_path_for(_scope)
        new_user_session_path(locale: I18n.locale)
      end
    end
  end
end
