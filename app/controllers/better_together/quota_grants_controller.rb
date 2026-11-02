# frozen_string_literal: true

module BetterTogether
  # Admin CRUD for quota grant overrides, plus a read-only usage overview
  # across every owner on the platform, so an admin can see who's close to a
  # cap before anyone requests a grant.
  class QuotaGrantsController < ApplicationController
    OWNER_TYPES = %w[BetterTogether::Person BetterTogether::Community].freeze

    before_action :set_platform
    before_action :set_quota_grant, only: %i[edit update destroy]
    after_action :verify_authorized
    rescue_from Pundit::NotAuthorizedError, with: :render_not_found

    def index
      authorize build_quota_grant

      @quotas_overview = Quota.where(platform_id: @platform.id)
                              .includes(:owner, :quota_balances)
                              .sort_by { |quota| -percent_used(quota) }
      @quota_grants = @platform.quota_grants
                               .includes(:owner, :granted_by)
                               .order(Arel.sql('CASE WHEN expires_at IS NULL OR expires_at > NOW() THEN 0 ELSE 1 END'),
                                      :quota_type, created_at: :desc)
    end

    def new
      @quota_grant = build_quota_grant(owner: find_prefill_owner)
      authorize @quota_grant
    end

    def edit
      authorize @quota_grant
    end

    def create
      @quota_grant = build_quota_grant(quota_grant_params)
      @quota_grant.granted_by = current_user&.person
      authorize @quota_grant

      if @quota_grant.save
        redirect_to platform_quota_grants_path(@platform),
                    status: :see_other,
                    notice: t('better_together.quota_grants.created', default: 'Quota grant created.')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @quota_grant

      if @quota_grant.update(quota_grant_update_params)
        redirect_to platform_quota_grants_path(@platform),
                    status: :see_other,
                    notice: t('better_together.quota_grants.updated', default: 'Quota grant updated.')
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @quota_grant
      @quota_grant.revoke!

      redirect_to platform_quota_grants_path(@platform),
                  status: :see_other,
                  notice: t('better_together.quota_grants.revoked', default: 'Quota grant revoked.')
    end

    private

    def set_platform
      @platform = Platform.friendly.find(params[:platform_id])
    end

    def set_quota_grant
      @quota_grant = @platform.quota_grants.find(params[:id])
    end

    def build_quota_grant(attributes = {})
      @platform.quota_grants.build(attributes)
    end

    def find_prefill_owner
      return nil unless OWNER_TYPES.include?(params[:owner_type])

      params[:owner_type].constantize.find_by(id: params[:owner_id])
    end

    def percent_used(quota)
      limit = quota.effective_limit
      return 0 if limit.zero?

      consumed = quota.current_balance&.consumed.to_i
      ((consumed.to_f / limit) * 100).round
    end

    def quota_grant_params
      params.require(:quota_grant).permit(:owner_type, :owner_id, :quota_type, :limit, :expires_at, :reason)
    end

    def quota_grant_update_params
      params.require(:quota_grant).permit(:quota_type, :limit, :expires_at, :reason)
    end
  end
end
