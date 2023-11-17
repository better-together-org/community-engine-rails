module BetterTogether
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    before_action :check_platform_setup

    private

    def check_platform_setup
      host_platform = helpers.host_platform

      if !host_platform.persisted? && !helpers.host_setup_wizard.completed?
        redirect_to setup_wizard_path
      end
    end
  end
end
