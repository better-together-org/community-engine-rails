# frozen_string_literal: true

module BetterTogether
  # Admin CRUD for platform domains (subdomain aliases and custom domains).
  # Nested under platforms — all actions are scoped to a specific platform.
  # Requires manage_platform permission (enforced via route constraint + Pundit).
  class PlatformDomainsController < ApplicationController
    before_action :set_platform
    before_action :set_platform_domain, only: %i[edit update destroy]
    after_action :verify_authorized

    # GET /host/platforms/:platform_id/platform_domains
    def index
      authorize @platform.platform_domains.build
      @platform_domains = @platform.platform_domains.order(primary_flag: :desc, created_at: :asc)
    end

    # GET /host/platforms/:platform_id/platform_domains/new
    def new
      @platform_domain = @platform.platform_domains.build
      authorize @platform_domain
    end

    # GET /host/platforms/:platform_id/platform_domains/:id/edit
    def edit
      authorize @platform_domain
    end

    # POST /host/platforms/:platform_id/platform_domains
    def create
      @platform_domain = @platform.platform_domains.build(platform_domain_params)
      authorize @platform_domain

      if @platform_domain.save
        redirect_to platform_platform_domains_path(@platform),
                    status: :see_other,
                    notice: t('better_together.platform_domains.created')
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /host/platforms/:platform_id/platform_domains/:id
    def update
      authorize @platform_domain

      if @platform_domain.update(platform_domain_params)
        redirect_to platform_platform_domains_path(@platform),
                    status: :see_other,
                    notice: t('better_together.platform_domains.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /host/platforms/:platform_id/platform_domains/:id
    def destroy
      authorize @platform_domain

      if @platform_domain.primary_flag?
        redirect_to platform_platform_domains_path(@platform),
                    status: :see_other,
                    alert: t('better_together.platform_domains.cannot_destroy_primary')
        return
      end

      @platform_domain.destroy
      redirect_to platform_platform_domains_path(@platform),
                  status: :see_other,
                  notice: t('better_together.platform_domains.destroyed')
    end

    private

    def set_platform
      # Routes use platform.to_param which returns the FriendlyId slug.
      # Use Platform.friendly.find so FriendlyId + Mobility handle the i18n lookup.
      @platform = Platform.friendly.find(params[:platform_id])
    end

    def set_platform_domain
      @platform_domain = @platform.platform_domains.find(params[:id])
    end

    def platform_domain_params
      params.require(:platform_domain).permit(:hostname, :primary_flag, :share_domain, :active)
    end
  end
end
