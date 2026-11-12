# frozen_string_literal: true

module BetterTogether
  module Billing
    # "Plan and usage" for a hosted platform's steward: the plan this platform is on with the host (the plan held for the
    # platform or its community), whether it is paid up, when it renews, and how much of each allowance is used. The data
    # is the host's billing records; only what is held for this platform is read, and only a steward of this platform sees it.
    class HostingPlansController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def show
        authorize BetterTogether::Billing::HostedAccount, :plan?, policy_class: HostedBillingPolicy
        @host = BetterTogether::Platform.host.first
        @entitlements = hosting_entitlements
        @terms = hosting_terms
        @meters = meters_for(@entitlements)
      end

      private

      # Reachable whether or not billing is on for this platform: the plan is the host's, not the platform's own.
      def billing_available? = BetterTogether::Billing::Configuration.requested? && !billing_owner&.host?

      # Who the plan is held for: this platform, and its community.
      def owners = [billing_owner, billing_owner.community].compact

      def hosting_entitlements
        return BetterTogether::Billing::Entitlement.none unless @host

        @host.billing_entitlements.where(beneficiary: owners).includes(:plan, :beneficiary, grants: []).order(created_at: :desc)
      end

      def hosting_terms
        return BetterTogether::Billing::SubscriptionTerm.none unless @host

        @host.billing_subscription_terms.where(beneficiary: owners).includes(:plan, :pay_subscription)
      end

      def meters_for(entitlements)
        entitlements.select(&:live?).flat_map { |entitlement| entitlement.grants.applied.allowances.map { |grant| [entitlement, grant] } }
                                    .to_h do |entitlement, grant|
          [[entitlement.id, grant.quota_type], Entitlements::Meter.for(owner: entitlement.beneficiary, type: grant.quota_type)]
        end
      end
    end
  end
end
