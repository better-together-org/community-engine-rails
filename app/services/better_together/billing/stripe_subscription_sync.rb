# frozen_string_literal: true

module BetterTogether
  module Billing
    # Synchronizes a Stripe subscription object into the local CE billing read model.
    class StripeSubscriptionSync # rubocop:todo Metrics/ClassLength
      Result = Struct.new(
        :synced,
        :billable_owner,
        :beneficiary,
        :billing_subscription,
        :billing_plan,
        :reason,
        keyword_init: true
      ) do
        def community
          beneficiary if beneficiary.is_a?(BetterTogether::Community)
        end

        def person
          beneficiary if beneficiary.is_a?(BetterTogether::Person)
        end
      end

      # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      def call(subscription:, billable_owner: nil, beneficiary: nil, source: 'stripe_sync', event: nil,
               checkout_session_id: nil)
        resolved_billable_owner = billable_owner || resolve_billable_owner(subscription)
        return Result.new(synced: false, reason: :billable_owner_not_found) unless resolved_billable_owner

        resolved_beneficiary = beneficiary || resolve_beneficiary(subscription, billable_owner: resolved_billable_owner)
        return Result.new(billable_owner: resolved_billable_owner, synced: false, reason: :beneficiary_not_found) unless resolved_beneficiary

        billing_plan = resolve_billing_plan(subscription)
        unless billing_plan
          return Result.new(
            billable_owner: resolved_billable_owner,
            beneficiary: resolved_beneficiary,
            synced: false,
            reason: :billing_plan_not_found
          )
        end

        persist_subscription(
          subscription,
          build_context(
            billable_owner: resolved_billable_owner,
            beneficiary: resolved_beneficiary,
            billing_plan:,
            source:,
            event:,
            checkout_session_id:
          )
        )
      end
      # rubocop:enable Metrics/MethodLength, Metrics/ParameterLists

      private

      def build_subscription(subscription)
        BetterTogether::Billing::Subscription.find_or_initialize_by(
          processor: 'stripe',
          processor_subscription_id: subscription.id
        )
      end

      def subscription_attributes(subscription, context)
        subscription_state_attributes(subscription).merge(
          legacy_community_attributes(context)
        ).merge(
          ownership_attributes(context)
        ).merge(
          sync_tracking_attributes(context)
        )
      end

      def subscription_state_attributes(subscription)
        {
          pay_customer_id: stripe_customer_id(subscription),
          status: normalize_status(subscription.status),
          current_period_start: stripe_timestamp(subscription.current_period_start),
          current_period_end: stripe_timestamp(subscription.current_period_end),
          cancel_at_period_end: ActiveModel::Type::Boolean.new.cast(subscription.cancel_at_period_end),
          metadata: object_metadata(subscription)
        }
      end

      def ownership_attributes(context)
        {
          billable_owner: context[:billable_owner],
          beneficiary: context[:beneficiary],
          billing_plan: context[:billing_plan]
        }
      end

      def legacy_community_attributes(context)
        community = compatibility_community(context)
        return {} unless community

        { community_id: community.id }
      end

      def sync_tracking_attributes(context)
        {
          last_synced_at: Time.current,
          sync_source: context[:source],
          latest_processor_event_id: context[:event]&.id,
          latest_checkout_session_id: context[:checkout_session_id]
        }
      end

      def resolve_billable_owner(subscription)
        metadata = object_metadata(subscription)

        OwnershipResolver.resolve_billable_owner(
          metadata:,
          fallback_owner: pay_customer_for(subscription)&.owner
        )
      end

      def resolve_beneficiary(subscription, billable_owner:)
        metadata = object_metadata(subscription)

        OwnershipResolver.resolve_beneficiary(
          metadata:,
          billable_owner:
        )
      end

      def resolve_billing_plan(subscription)
        metadata = object_metadata(subscription)

        BetterTogether::Billing::Plan.find_by(id: metadata['bt_billing_plan_id']) ||
          BetterTogether::Billing::Plan.find_by(identifier: metadata['bt_billing_plan_identifier']) ||
          BetterTogether::Billing::Plan.find_by(stripe_price_id: stripe_price_id(subscription))
      end

      def pay_customer_for(subscription)
        customer_id = stripe_customer_id(subscription)
        return if customer_id.blank?

        Pay::Customer.find_by(processor: 'stripe', processor_id: customer_id)
      end

      def stripe_customer_id(subscription)
        return subscription.customer if subscription.respond_to?(:customer)

        nil
      end

      def object_metadata(object)
        return {} unless object.respond_to?(:metadata)

        object.metadata.to_h
      end

      def stripe_price_id(subscription)
        line_item_price_id(subscription) || legacy_plan_price_id(subscription)
      end

      def line_item_price_id(subscription)
        return unless subscription.respond_to?(:items) && subscription.items.respond_to?(:data)

        first_item = subscription.items.data.first
        return unless first_item
        return unless first_item.respond_to?(:price)

        price = first_item.price
        price.id if price.respond_to?(:id)
      end

      def legacy_plan_price_id(subscription)
        return unless subscription.respond_to?(:plan)

        plan = subscription.plan
        plan.id if plan.respond_to?(:id)
      end

      def normalize_status(status)
        normalized = status.to_s
        return normalized if BetterTogether::Billing::Subscription::STATUSES.include?(normalized)

        'incomplete'
      end

      def stripe_timestamp(value)
        return if value.blank?

        Time.zone.at(value.to_i)
      end

      def compatibility_community(context)
        [context[:beneficiary], context[:billable_owner]].find do |record|
          record.is_a?(BetterTogether::Community)
        end
      end

      # rubocop:disable Metrics/ParameterLists
      def build_context(billable_owner:, beneficiary:, billing_plan:, source:, event:, checkout_session_id:)
        {
          billable_owner:,
          beneficiary:,
          billing_plan:,
          source:,
          event:,
          checkout_session_id:
        }
      end
      # rubocop:enable Metrics/ParameterLists

      def persist_subscription(subscription, context)
        billing_subscription = build_subscription(subscription)
        billing_subscription.assign_attributes(subscription_attributes(subscription, context))
        billing_subscription.save!

        Result.new(
          synced: true,
          billable_owner: context[:billable_owner],
          beneficiary: context[:beneficiary],
          billing_subscription:,
          billing_plan: context[:billing_plan],
          reason: :synced
        )
      end
    end
  end
end
