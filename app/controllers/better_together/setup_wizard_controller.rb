module BetterTogether
  class SetupWizardController < ApplicationController
    skip_before_action :check_platform_setup

    def step_one
      @platform = BetterTogether::Platform.new(
        url: helpers.base_url, 
        privacy: 'public', 
        time_zone: Time.zone.name
      )
      # Render the form for creating the platform
    end

    def create_host_platform
      @platform = BetterTogether::Platform.new(platform_params)
      @platform.set_as_host
      @platform.build_host_community

      ActiveRecord::Base.transaction do
        if @platform.save
          flash[:notice] = 'Platform created successfully. Please set your personal and login details.'
          redirect_to setup_wizard_step_two_path
        else
          render :step_one
        end
      end
    rescue ActiveRecord::RecordInvalid
      render :step_one
    end

    def step_two
      # Step two logic (creating an administrator)
    end

    # More steps can be added here...

    private

    def platform_params
      params.require(:platform).permit(:name, :description, :url, :time_zone, :privacy)
    end

    def community_params
      # Define community parameters here...
    end
  end
end
