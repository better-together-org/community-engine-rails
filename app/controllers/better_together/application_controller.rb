module BetterTogether
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    before_action :check_platform_setup

    private

    def check_platform_setup
      host_platform = helpers.host_platform

      # unless host_platform.persisted?
      #   flash[:info] = 'Please configure your platform in the setup wizard before continuing.'
      #   redirect_to setup_wizard_step_one_path
      # end
    end
  end
end
