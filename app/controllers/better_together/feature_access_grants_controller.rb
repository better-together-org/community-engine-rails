# frozen_string_literal: true

module BetterTogether
  # Admin CRUD for explicit per-person feature gate access grants.
  class FeatureAccessGrantsController < ApplicationController
    before_action :set_platform
    before_action :set_feature_access_grant, only: %i[edit update destroy]
    after_action :verify_authorized
    rescue_from Pundit::NotAuthorizedError, with: :render_not_found

    def index
      authorize build_feature_access_grant
      @feature_access_grants = @platform.feature_access_grants
                                        .includes(:person, :granted_by_person)
                                        .order(Arel.sql('CASE WHEN revoked_at IS NULL THEN 0 ELSE 1 END'), :feature_key,
                                               expires_at: :asc, created_at: :desc)
    end

    def new
      @feature_access_grant = build_feature_access_grant(access_level: 'beta')
      authorize @feature_access_grant
    end

    def edit
      authorize @feature_access_grant
    end

    def create
      @feature_access_grant = build_feature_access_grant(feature_access_grant_params)
      @feature_access_grant.granted_by_person = current_user&.person
      authorize @feature_access_grant

      if @feature_access_grant.save
        redirect_to platform_feature_access_grants_path(@platform),
                    status: :see_other,
                    notice: t('better_together.feature_access_grants.created',
                              default: 'Feature access grant created.')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @feature_access_grant

      if @feature_access_grant.update(feature_access_grant_update_params)
        redirect_to platform_feature_access_grants_path(@platform),
                    status: :see_other,
                    notice: t('better_together.feature_access_grants.updated',
                              default: 'Feature access grant updated.')
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @feature_access_grant
      @feature_access_grant.revoke!

      redirect_to platform_feature_access_grants_path(@platform),
                  status: :see_other,
                  notice: t('better_together.feature_access_grants.revoked',
                            default: 'Feature access grant revoked.')
    end

    private

    def set_platform
      @platform = Platform.friendly.find(params[:platform_id])
    end

    def set_feature_access_grant
      @feature_access_grant = @platform.feature_access_grants.find(params[:id])
    end

    def build_feature_access_grant(attributes = {})
      @platform.feature_access_grants.build(attributes)
    end

    def feature_access_grant_params
      params.require(:feature_access_grant).permit(:person_id, :feature_key, :access_level, :expires_at, :notes)
    end

    def feature_access_grant_update_params
      params.require(:feature_access_grant).permit(:feature_key, :access_level, :expires_at, :notes)
    end
  end
end
