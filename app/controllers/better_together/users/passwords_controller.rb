# frozen_string_literal: true

module BetterTogether
  module Users
    class PasswordsController < ::Devise::PasswordsController # rubocop:todo Style/Documentation
      include DeviseLocales

      skip_before_action :check_platform_privacy
    end
  end
end
