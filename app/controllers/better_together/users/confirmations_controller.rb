# frozen_string_literal: true

module BetterTogether
  module Users
    class ConfirmationsController < ::Devise::ConfirmationsController
      include DeviseLocales
      skip_before_action :check_platform_privacy
    end
  end
end
