# frozen_string_literal: true

module BetterTogether
  module Billing
    # Persists Stripe webhook events and syncs subscription state into BTS billing tables.
    # rubocop:disable Metrics/ClassLength
    class StripeEventProcessor
      def call(event)
        community = resolve_community(event)
        subscription = sync_subscription(event, community)
        persist_success(event, community, subscription)
      rescue StandardError => e
        persist_failure(event, e)
        raise
      end

      private

      def sync_subscription(event, community)
        return unless subscription_event?(event) && community

        data_object = event.data.object
        billing_plan = resolve_billing_plan(data_object)
        return unless billing_plan

        build_subscription(data_object).tap do |subscription|
          subscription.assign_attributes(subscription_attributes(data_object, community, billing_plan))
          subscription.save!
        end
      end

      def resolve_community(event)
        data_object = event.data.object
        metadata = object_metadata(data_object)

        BetterTogether::Community.find_by(id: metadata['bt_community_id']) ||
          pay_customer_for(data_object)&.owner
      end

      def resolve_billing_plan(data_object)
        metadata = object_metadata(data_object)
        BetterTogether::Billing::Plan.find_by(id: metadata['bt_billing_plan_id']) ||
          BetterTogether::Billing::Plan.find_by(identifier: metadata['bt_billing_plan_identifier']) ||
          BetterTogether::Billing::Plan.find_by(stripe_price_id: stripe_price_id(data_object))
      end

      def build_subscription(data_object)
        BetterTogether::Billing::Subscription.find_or_initialize_by(
          processor: 'stripe',
          processor_subscription_id: data_object.id
        )
      end

      def subscription_attributes(data_object, community, billing_plan)
        {
          community:,
          billing_plan:,
          pay_customer_id: data_object.customer,
          status: normalize_status(data_object.status),
          current_period_start: stripe_timestamp(data_object.current_period_start),
          current_period_end: stripe_timestamp(data_object.current_period_end),
          cancel_at_period_end: ActiveModel::Type::Boolean.new.cast(data_object.cancel_at_period_end),
          metadata: object_metadata(data_object)
        }
      end

      def pay_customer_for(data_object)
        customer_id = if data_object.respond_to?(:customer)
                        data_object.customer
                      elsif data_object.respond_to?(:object) && data_object.object.respond_to?(:customer)
                        data_object.object.customer
                      end
        return if customer_id.blank?

        Pay::Customer.find_by(processor: 'stripe', processor_id: customer_id)
      end

      def object_metadata(data_object)
        return {} unless data_object.respond_to?(:metadata)

        data_object.metadata.to_h
      end

      def stripe_price_id(data_object)
        line_item_price_id(data_object) || legacy_plan_price_id(data_object)
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

      def subscription_event?(event)
        event.type.start_with?('customer.subscription.')
      end

      def processing_status_for(event, subscription)
        return 'processed' if subscription_event?(event) && subscription.present?
        return 'ignored' unless subscription_event?(event)

        'ignored'
      end

      def persist_success(event, community, subscription)
        billing_event = billing_event_for(event)
        billing_event.assign_attributes(
          event_type: event.type,
          payload: event.to_hash,
          community: community,
          billing_subscription: subscription,
          processed_at: Time.current,
          processing_status: processing_status_for(event, subscription),
          error_message: nil
        )
        billing_event.save!
      end

      def billing_event_for(event)
        BetterTogether::Billing::Event.find_or_initialize_by(
          processor: 'stripe',
          event_id: event.id
        )
      end

      def line_item_price_id(data_object)
        return unless data_object.respond_to?(:items) && data_object.items.respond_to?(:data)

        first_item = data_object.items.data.first
        return unless first_item
        return unless first_item.respond_to?(:price)

        price = first_item.price
        price.id if price.respond_to?(:id)
      end

      def legacy_plan_price_id(data_object)
        return unless data_object.respond_to?(:plan)

        plan = data_object.plan
        plan.id if plan.respond_to?(:id)
      end

      def persist_failure(event, error)
        billing_event = billing_event_for(event)
        billing_event.assign_attributes(
          event_type: event.type,
          payload: event.to_hash,
          processed_at: Time.current,
          processing_status: 'failed',
          error_message: error.message
        )
        billing_event.save!
      rescue StandardError
        nil
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
