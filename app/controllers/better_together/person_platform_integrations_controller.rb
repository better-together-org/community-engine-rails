# frozen_string_literal: true

module BetterTogether
  # Allows for the management of PersonPlatformIntegrations
  class PersonPlatformIntegrationsController < ApplicationController
    before_action :set_person_platform_integration, only: %i[show edit update destroy]

    # GET /better_together/person_platform_integrations
    def index
      @person_platform_integrations = BetterTogether::PersonPlatformIntegration.all
    end

    # GET /better_together/person_platform_integrations/1
    def show; end

    # GET /better_together/person_platform_integrations/new
    def new
      @person_platform_integration = BetterTogether::PersonPlatformIntegration.new
    end

    # GET /better_together/person_platform_integrations/1/edit
    def edit; end

    # POST /better_together/person_platform_integrations
    def create
      # rubocop:todo Layout/LineLength
      @better_together_person_platform_integration = BetterTogether::PersonPlatformIntegration.new(person_platform_integration_params)
      # rubocop:enable Layout/LineLength

      if @person_platform_integration.save
        redirect_to @person_platform_integration, notice: 'PersonPlatformIntegration was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /better_together/person_platform_integrations/1
    def update
      if @person_platform_integration.update(person_platform_integration_params)
        redirect_to @person_platform_integration, notice: 'PersonPlatformIntegration was successfully updated.',
                                                  status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /better_together/person_platform_integrations/1
    def destroy
      @person_platform_integration.destroy!
      redirect_to person_platform_integrations_url, notice: 'PersonPlatformIntegration was successfully destroyed.',
                                                    status: :see_other
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_person_platform_integration
      @person_platform_integration = BetterTogether::PersonPlatformIntegration.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def person_platform_integration_params
      params.require(:person_platform_integration).permit(:provider, :uid, :token, :secret, :profile_url, :user_id)
    end
  end
end
