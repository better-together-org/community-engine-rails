# frozen_string_literal: true

module BetterTogether
  module Billing
    # The signed-in person's billing page: their active plans, latest orders, store credit and what they have access to,
    # each with a link to its full page. Only their own are ever loaded.
    class HubsController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def show
        authorize BetterTogether::Billing::Order, :index?
        @terms = own_terms.limit(5)
        @orders = billing_owner.billing_orders.bought_by(person).newest_first.limit(5)
        @add_ons = extras_for_held_plans
        load_credit_and_access
      end

      private

      def person = current_user.person

      # Add-ons this person may buy on their own because they hold a plan the add-on extends.
      def extras_for_held_plans
        billing_owner.billing_plans.sold_by_platform.active.add_on.order(:amount_cents, :identifier).limit(20)
                     .select { |add_on| policy(add_on).buy_alone? }.first(6)
      end

      def load_credit_and_access
        @credit_accounts = billing_owner.billing_credit_accounts.where(holder: person).order(:currency)
        @access_count = Entitlements::ForPerson.call(platform: billing_owner, person:).live.count
      end

      def own_terms
        billing_owner.billing_subscription_terms.local.joins(pay_subscription: :customer)
                     .where(pay_customers: { owner_type: BetterTogether::Person.name, owner_id: person.id })
                     .where(pay_subscriptions: { status: %w[active trialing past_due] })
                     .includes(:plan, pay_subscription: :customer).order(created_at: :desc)
      end
    end
  end
end
