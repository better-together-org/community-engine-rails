# frozen_string_literal: true

module BetterTogether
  module Billing
    # A steward adds to, and removes from, what a plan includes. The kinds come from an allow-list and each kind's
    # parameters are checked by its handler, so a plan can only name roles, features and quotas the platform
    # provided for. A change brings the plan's current subscribers and buyers up to date (in a job).
    class PlanGrantsController < ApplicationController
      include OwnerScoped

      PARAMETERS = {
        'membership_role' => %w[joinable community_id role],
        'feature_access' => %w[feature_key access_level],
        'quota_allowance' => %w[quota_type amount]
      }.freeze

      before_action :set_plan
      after_action :verify_authorized

      def create
        grant = @plan.plan_grants.build(platform_id: billing_owner.id, kind: params[:kind].to_s, parameters: grant_parameters,
                                        position: @plan.plan_grants.size)
        authorize grant
        saved = grant.save
        SyncPlanEntitlementsJob.perform_later(@plan) if saved
        back(saved ? { notice: t('better_together.billing.plan_grants.added') } : { alert: t('better_together.billing.plan_grants.refused') })
      end

      def destroy
        grant = @plan.plan_grants.find(params[:id])
        authorize grant
        grant.destroy!
        SyncPlanEntitlementsJob.perform_later(@plan)
        back(notice: t('better_together.billing.plan_grants.removed'))
      end

      private

      def back(message) = redirect_to(billing_plan_path(@plan, locale: I18n.locale), **message)

      def set_plan
        @plan = billing_owner.billing_plans.sold_by_platform.find(params[:plan_id])
      end

      # Only the fields of the chosen kind, as text.
      def grant_parameters
        allowed = PARAMETERS.fetch(params[:kind].to_s, [])
        allowed.index_with { |name| params[name].to_s.strip }.compact_blank
      end
    end
  end
end
