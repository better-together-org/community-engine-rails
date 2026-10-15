# frozen_string_literal: true

module BetterTogether
  module Billing
    # Subscribes every registered processor's webhook events to Pay's delegator.
    # Run once after initialization, so extension gems have registered by then.
    module WebhookSubscriptions
      class << self
        def subscribe_all!
          BetterTogether::Billing.processor_names.each { |name| subscribe(name) }
        end

        private

        def subscribe(name)
          dispatcher = WebhookDispatcher.new(name)
          BetterTogether::Billing.processor_adapter(name).webhook_event_types.each do |event_type|
            next if subscribed.add?("#{name}:#{event_type}").nil?

            Pay::Webhooks.delegator.subscribe(event_type, dispatcher)
          end
        end

        def subscribed
          @subscribed ||= Concurrent::Set.new
        end
      end
    end
  end
end
