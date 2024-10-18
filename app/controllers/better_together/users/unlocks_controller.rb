# frozen_string_literal: true

module BetterTogether
  module Users
    class UnlocksController < ::Devise::UnlocksController
      include DeviseLocales
      skip_before_action :check_platform_privacy
    end
  end
end
