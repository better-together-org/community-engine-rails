# frozen_string_literal: true

module BetterTogether
  # Manages user's external platform integrations (OAuth connections).
  # Allows users to view, create, update, and remove their connected accounts
  # from external platforms like GitHub, Facebook, Google, etc.
  class PersonPlatformIntegrationsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_person_platform_integration, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index
    after_action :verify_policy_scoped, only: :index

    # GET /better_together/person_platform_integrations
    def index
      @person_platform_integrations = policy_scope(BetterTogether::PersonPlatformIntegration)
                                      .includes(:platform)
                                      .order(created_at: :desc)
    end

    # GET /better_together/person_platform_integrations/1
    def show
      authorize @person_platform_integration
    end

    # GET /better_together/person_platform_integrations/new
    def new
      @person_platform_integration = BetterTogether::PersonPlatformIntegration.new
      authorize @person_platform_integration
    end

    # GET /better_together/person_platform_integrations/1/edit
    def edit
      authorize @person_platform_integration
    end

    # POST /better_together/person_platform_integrations
    def create
      @person_platform_integration = BetterTogether::PersonPlatformIntegration.new(person_platform_integration_params)
      @person_platform_integration.user = current_user
      @person_platform_integration.person = current_user.person

      authorize @person_platform_integration

      if @person_platform_integration.save
        redirect_to @person_platform_integration, notice: 'PersonPlatformIntegration was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /better_together/person_platform_integrations/1
    def update
      authorize @person_platform_integration

      if @person_platform_integration.update(person_platform_integration_params)
        redirect_to @person_platform_integration, notice: 'PersonPlatformIntegration was successfully updated.',
                                                  status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /better_together/person_platform_integrations/1
    def destroy
      authorize @person_platform_integration

      if @person_platform_integration.destroy
        flash[:notice] = t('.success')
        redirect_to person_platform_integrations_path(locale:), status: :see_other
      else
        flash[:alert] = t('.error')
        redirect_to person_platform_integrations_path(locale:), status: :unprocessable_entity
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_person_platform_integration
      @person_platform_integration = BetterTogether::PersonPlatformIntegration.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def person_platform_integration_params
      params.require(:person_platform_integration).permit(
        :provider,
        :uid,
        :access_token,
        :access_token_secret,
        :refresh_token,
        :expires_at,
        :handle,
        :name,
        :profile_url,
        :person_id,
        :platform_id
      )
    end
  end
end
