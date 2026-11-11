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
      @env_providers = IdentityProviderCredentials.env_providers(@platform)
    end

    def new
      @identity_provider = @platform.platform_identity_providers.build(platform_domain_ids: own_domain_ids)
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

    helper_method :available_domains

    private

    # Domains this configuration may be allowed to serve: the platform's own, plus any active
    # domain when the platform is the host (so the host can share a provider with hosted platforms).
    def available_domains
      scope = PlatformDomain.active.includes(:platform).order(:hostname)
      @platform.host? ? scope : scope.where(platform_id: @platform.id)
    end

    def own_domain_ids
      @platform.platform_domains.active.pluck(:id)
    end

    def set_platform
      @platform = Platform.friendly.find(params[:platform_id])
    end

    def set_identity_provider
      @identity_provider = @platform.platform_identity_providers.find(params[:id])
    end

    # A blank secret on edit keeps the stored one; the strategy cannot change once created.
    def identity_provider_params
      permitted = params.require(:platform_identity_provider)
                        .permit(:strategy, :enabled, :client_id, :client_secret, :scopes, :issuer, platform_domain_ids: [])
      permitted.delete(:client_secret) if permitted[:client_secret].blank? && @identity_provider&.persisted?
      permitted.delete(:strategy) if @identity_provider&.persisted?
      restrict_domain_ids(permitted)
    end

    # Only domains the actor may allow can be submitted; never trust raw ids.
    def restrict_domain_ids(permitted)
      return permitted unless permitted.key?(:platform_domain_ids)

      allowed = available_domains.ids
      permitted[:platform_domain_ids] = Array(permitted[:platform_domain_ids]).compact_blank & allowed
      permitted
    end
  end
end
