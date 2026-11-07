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
      def mine
        person = current_user.person
        all = billing_owner.billing_entitlements
        all.where(beneficiary: person).or(all.where(pay_subscription_id: paid_subscription_ids(person)))
           .or(all.where(order_id: paid_order_ids(person)))
      end

      def paid_subscription_ids(person)
        billing_owner.billing_subscription_terms.joins(pay_subscription: :customer)
                     .where(pay_customers: { owner_type: BetterTogether::Person.name, owner_id: person.id }).select(:pay_subscription_id)
      end

      def paid_order_ids(person) = billing_owner.billing_orders.bought_by(person).select(:id)

      # [entitlement id, quota type] => the owner's usage, for each allowance a live entitlement carries.
      def meters_for(entitlements)
        entitlements.select(&:live?).flat_map { |entitlement| entitlement.grants.applied.allowances.map { |grant| [entitlement, grant] } }
                                    .to_h { |entitlement, grant| [[entitlement.id, grant.quota_type], Entitlements::Meter.for(owner: entitlement.beneficiary, type: grant.quota_type)] }
      end
    end
  end
end
