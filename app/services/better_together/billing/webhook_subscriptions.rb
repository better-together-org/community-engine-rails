# frozen_string_literal: true

module BetterTogether
  module Billing
    # Subscribes every registered processor's webhook events to Pay's delegator.
    # Run once after initialization, so extension gems have registered by then.
    module WebhookSubscriptions
      class << self
        # One processor that fails to build or subscribe is logged and reported, and
        # skipped; it must never stop the application (or `db:migrate`) from booting.
        def subscribe_all!
          BetterTogether::Billing.processor_names.each do |name|
            subscribe(name)
          rescue StandardError => e
            report_failure(name, e)
          end
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

        def report_failure(name, error)
          Rails.logger.error("[billing] could not subscribe #{name} webhooks: #{error.class}")
          BetterTogether.report_error(error, context: { processor: name })
        rescue StandardError
          nil
        end
      end
    end
  end
end
