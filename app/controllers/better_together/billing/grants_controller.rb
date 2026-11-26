# frozen_string_literal: true

module BetterTogether
  module Billing
    # A steward adds to, and removes from, what a product (or a plan, which is a product) includes. The kinds come from an
    # allow-list and each kind's parameters are checked by its handler, so only roles, features and quotas the platform provided
    # for can be named. A change brings the people who already bought it up to date (in a job).
    class GrantsController < ApplicationController
      include OwnerScoped

      PARAMETERS = {
        'membership_role' => %w[joinable community_id role],
        'feature_access' => %w[feature_key access_level],
        'quota_allowance' => %w[quota_type amount]
      }.freeze

      before_action :set_product
      after_action :verify_authorized

      def create
        grant = @product.grants.build(platform_id: billing_owner.id, kind: params[:kind].to_s, parameters: grant_parameters,
                                      position: @product.grants.size)
        authorize grant, policy_class: GrantPolicy
        saved = grant.save
        SyncPlanEntitlementsJob.perform_later(@product) if saved
        back(saved ? { notice: t('better_together.billing.grants.added') } : { alert: t('better_together.billing.grants.refused') })
      end

      def update # rubocop:disable Metrics/AbcSize
        grant = @product.grants.find(params[:id])
        authorize grant, policy_class: GrantPolicy
        saved = grant.kind == 'quota_allowance' && grant.update(parameters: grant.parameters.merge('amount' => params[:amount].to_s.strip))
        SyncPlanEntitlementsJob.perform_later(@product) if saved
        back(saved ? { notice: t('better_together.billing.grants.updated') } : { alert: t('better_together.billing.grants.refused') })
      end

      def destroy
        grant = @product.grants.find(params[:id])
        authorize grant, policy_class: GrantPolicy
        grant.destroy!
        SyncPlanEntitlementsJob.perform_later(@product)
        back(notice: t('better_together.billing.grants.removed'))
      end

      private

      def back(message)
        redirect_to(
          @product.is_a?(Plan) ? billing_plan_path(@product,
                                                   locale: I18n.locale) : billing_product_path(@product, locale: I18n.locale), **message
        )
      end

      def set_product
        @product = billing_owner.billing_products.sold_by_platform.find(params[:product_id])
      end

      def grant_parameters
        allowed = PARAMETERS.fetch(params[:kind].to_s, [])
        allowed.index_with { |name| params[name].to_s.strip }.compact_blank
      end
    end
  end
end
