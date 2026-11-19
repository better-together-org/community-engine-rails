# frozen_string_literal: true

module BetterTogether
  module Billing
    # Stewards see how the platform's quotas are used, who has paid allowances, and who is over, and choose how
    # strictly each quota type is enforced (off, shadow, soft, hard; shadow by default, which refuses nothing).
    class AllowancesController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Entitlement, :allowances?
        @types = BetterTogether::Quotas::Type.all
        @modes = @types.to_h { |type| [type.key, billing_owner.quota_enforcement_mode(type.key)] }
        @rows = rows
      end

      def update
        authorize BetterTogether::Billing::Entitlement, :set_enforcement?
        billing_owner.set_quota_enforcement!(params[:id], params[:mode])
        redirect_to billing_allowances_path(locale: I18n.locale), notice: t('better_together.billing.allowances.saved')
      rescue BetterTogether::Quotas::PlatformEnforcement::InvalidMode
        redirect_to billing_allowances_path(locale: I18n.locale), alert: t('better_together.billing.allowances.refused')
      end

      private

      # Who has a paid allowance on this platform (people are not tied to one platform, so they are found through
      # their entitlements), and any community or platform quota here that is over its limit, with usage.
      def rows
        (allowance_rows + over_limit_rows).uniq { |row| row[:quota].id }
      end

      def allowance_rows
        billing_owner.billing_entitlements.live.includes(:beneficiary, :grants).flat_map do |entitlement|
          entitlement.grants.applied.allowances.filter_map { |grant| row_for(entitlement.beneficiary, grant.quota_type) }
        end
      end

      def over_limit_rows
        BetterTogether::Quota.where(platform_id: billing_owner.id).includes(:owner).limit(500).filter_map do |quota|
          row = row_for(quota.owner, quota.quota_type)
          row if row&.dig(:reading)&.over?
        end
      end

      def row_for(owner, type)
        quota = BetterTogether::Quota.find_by(owner:, quota_type: type)
        { quota:, reading: Entitlements::Meter.for(owner:, type:) } if quota
      end
    end
  end
end
