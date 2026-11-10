# frozen_string_literal: true

module BetterTogether
  # Host-dashboard CRUD for a platform's OAuth sign-in providers (credentials per
  # identity provider). Scoped to one platform and authorized per platform.
  # The client secret is write-only: it is never rendered back.
  class PlatformIdentityProvidersController < ApplicationController
    before_action :set_platform
    before_action :set_identity_provider, only: %i[edit update destroy]
    after_action :verify_authorized

    # GET /host/platforms/:platform_id/identity_providers
    def index
      authorize @platform.platform_identity_providers.build
      @identity_providers = @platform.platform_identity_providers.order(:position, :created_at)
    end

    def new
      @identity_provider = @platform.platform_identity_providers.build
      authorize @identity_provider
    end

    def edit
      authorize @identity_provider
    end

    def create
      @identity_provider = @platform.platform_identity_providers.build(identity_provider_params)
      authorize @identity_provider

      if @identity_provider.save
        redirect_to platform_platform_identity_providers_path(@platform), status: :see_other,
                                                                          notice: t('.created')
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      authorize @identity_provider

      if @identity_provider.update(identity_provider_params)
        redirect_to platform_platform_identity_providers_path(@platform), status: :see_other,
                                                                          notice: t('.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @identity_provider
      @identity_provider.destroy
      redirect_to platform_platform_identity_providers_path(@platform), status: :see_other,
                                                                        notice: t('.destroyed')
    end

    private

    def set_platform
      @platform = Platform.friendly.find(params[:platform_id])
    end

    def set_identity_provider
      @identity_provider = @platform.platform_identity_providers.find(params[:id])
    end

    # A blank secret on edit keeps the stored one; the strategy cannot change once created.
    def identity_provider_params
      permitted = params.require(:platform_identity_provider)
                        .permit(:strategy, :enabled, :client_id, :client_secret, :scopes)
      permitted.delete(:client_secret) if permitted[:client_secret].blank? && @identity_provider&.persisted?
      permitted.delete(:strategy) if @identity_provider&.persisted?
      permitted
    end
  end
end
