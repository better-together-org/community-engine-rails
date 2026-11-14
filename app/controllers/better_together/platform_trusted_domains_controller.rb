# frozen_string_literal: true

module BetterTogether
  # Steward CRUD for a platform's trusted email domains, nested under the platform.
  # Every change writes an audit entry; removing a domain never touches existing accounts or memberships.
  class PlatformTrustedDomainsController < ApplicationController
    before_action :set_platform
    before_action :set_trusted_domain, only: %i[edit update destroy]
    after_action :verify_authorized

    def index
      authorize @platform.platform_trusted_domains.build
      @trusted_domains = @platform.platform_trusted_domains.includes(:role).order(:domain)
      @account_counts = TrustedDomainEvent.where(platform: @platform, event_type: 'account_created')
                                          .group(:platform_trusted_domain_id).count
      @recent_events = @platform.trusted_domain_events.includes(:subject, :actor).newest_first.limit(20)
    end

    def new
      @trusted_domain = @platform.platform_trusted_domains.build
      authorize @trusted_domain
    end

    def edit
      authorize @trusted_domain
    end

    def create
      @trusted_domain = @platform.platform_trusted_domains.build(trusted_domain_params)
      @trusted_domain.created_by = current_user.person
      authorize @trusted_domain

      if @trusted_domain.save
        audit('domain_added', @trusted_domain)
        redirect_with(:created)
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @trusted_domain

      if @trusted_domain.update(trusted_domain_params)
        audit('domain_updated', @trusted_domain)
        redirect_with(:updated)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @trusted_domain

      audit('domain_removed', @trusted_domain)
      @trusted_domain.destroy!
      redirect_with(:destroyed)
    end

    private

    def set_platform
      @platform = Platform.friendly.find(params[:platform_id])
    end

    def set_trusted_domain
      @trusted_domain = @platform.platform_trusted_domains.find(params[:id])
    end

    def trusted_domain_params
      params.require(:platform_trusted_domain)
            .permit(:domain, :role_id, :enabled, :include_subdomains, :public_domain_confirmed,
                    :role_ceiling_confirmed, :note)
    end

    def redirect_with(key)
      redirect_to platform_platform_trusted_domains_path(@platform), status: :see_other,
                                                                     notice: t("better_together.platform_trusted_domains.#{key}")
    end

    def audit(event_type, trusted_domain)
      TrustedDomainEvent.create!(
        platform: @platform, platform_trusted_domain: event_type == 'domain_removed' ? nil : trusted_domain,
        actor: current_user.person, event_type:, via: 'steward', domain: trusted_domain.domain,
        role_identifier: trusted_domain.role&.identifier,
        details: trusted_domain.slice(:enabled, :include_subdomains, :public_domain_confirmed, :role_ceiling_confirmed)
      )
    end
  end
end
