module BetterTogether
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    before_action :check_platform_setup

    # helper 'better_together/application'

    private

    def check_platform_setup
      unless BetterTogether::Platform.exists?(host: true)
        flash[:info] = 'Please configure your platform in the setup wizard before continuing.'
        redirect_to setup_wizard_step_one_path
      end
    end
  end
end
