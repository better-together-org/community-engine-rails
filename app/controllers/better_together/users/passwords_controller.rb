# frozen_string_literal: true

module BetterTogether
  module Users
    class PasswordsController < ::Devise::PasswordsController
      include DeviseLocales
      skip_before_action :check_platform_privacy
    end
  end
end
