# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Links a subscription a processor created and renews (a `Pay::Subscription` Pay synced) to the order
      # that bought it, by making its terms. The processor renews it, so no periods are made here and nothing
      # renews it locally; its state stays Pay's. A processor extension calls this when it sees the order id
      # carried in the subscription's metadata. Safe to repeat.
      class Adopt
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(pay_subscription:, order:)
          @pay_subscription = pay_subscription
          @order = order
        end

        def call
          existing = order.platform.billing_subscription_terms.find_by(pay_subscription_id: pay_subscription.id)
          return existing if existing

          check!
          SubscriptionTerm.transaction do
            term = build
            order.update!(pay_subscription:, subject: term)
            ActiveRecord.after_all_transactions_commit { SyncEntitlementJob.perform_later(pay_subscription.id) }
            term
          end
        end

        private

        attr_reader :pay_subscription, :order

        def plan = @plan ||= Start.single_plan(order)

        def check!
          raise Refused, 'that subscription is on another platform' if pay_subscription.platform_id != order.platform_id
          raise Refused, 'that order is not for one recurring plan' unless plan&.recurring?
        end

        def build = order.platform.billing_subscription_terms.create!(term_attributes)

        def term_attributes
          { pay_subscription:, plan:, beneficiary: order.on_behalf_of, payment_method: pay_subscription.customer.processor,
            unit_amount_cents: order.line_items.first.unit_amount_cents, currency: order.currency, anchor_at: pay_subscription.created_at }
        end
      end
    end
  end
end
