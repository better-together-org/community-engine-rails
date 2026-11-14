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
        @orders = billing_owner.billing_orders.bought_by(person).newest_first.limit(5).to_a
        @refunded_by_order = refunded_by_order(@orders)
        load_credit_and_access
      end

      private

      def person = current_user.person

      # What has been given back on each of these orders (money that failed to move is not counted).
      def refunded_by_order(orders)
        billing_owner.billing_orders.where(id: orders.map(&:id)).joins(payments: :refunds)
                     .where(refunds_table => { status: Refund::COUNTED })
                     .group("#{orders_table}.id").sum("#{refunds_table}.amount_cents")
      end

      def refunds_table = Refund.arel_table.name

      def orders_table = Order.arel_table.name

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
