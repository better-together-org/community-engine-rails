# frozen_string_literal: true

module BetterTogether
  module Billing
    # "My access": what the signed-in person has because of a plan they pay for (or one paid for them), where each
    # stands, and the allowances they have with how much is used. Only their own are ever loaded.
    class EntitlementsController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Entitlement, :own?
        @entitlements = mine.includes(:plan, :beneficiary, grants: []).order(created_at: :desc)
        @meters = meters_for(@entitlements)
      end

      private

      # Those it is for, and those they pay for.
      def mine = Entitlements::ForPerson.call(platform: billing_owner, person: current_user.person)

      # [entitlement id, quota type] => the owner's usage, for each allowance a live entitlement carries.
      def meters_for(entitlements)
        entitlements.select(&:live?).flat_map { |entitlement| entitlement.grants.applied.allowances.map { |grant| [entitlement, grant] } }
                                    .to_h { |entitlement, grant| [[entitlement.id, grant.quota_type], Entitlements::Meter.for(owner: entitlement.beneficiary, type: grant.quota_type)] }
      end
    end
  end
end
