# frozen_string_literal: true

module BetterTogether
  module Billing
    # A live look at a plan's processor-side price and product, and where it differs from
    # the copy kept here. Shown on the plan page so a steward sees the processor's truth
    # without opening its dashboard. Cached briefly to spare the processor.
    class PlanSnapshot
      Result = Struct.new(:price, :product, :drift, :error, keyword_init: true)

      CACHE_TTL = 30.seconds
      COMPARED = { amount_cents: :amount_cents, currency: :currency, billing_interval: :interval, active: :active }.freeze

      def self.call(plan) = new(plan).call

      def initialize(plan)
        @plan = plan
      end

      def call
        return Result.new(drift: [], error: :not_linked) unless @plan.linked? && @plan.sync_supported?

        price, product = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch }
        Result.new(price:, product:, drift: drift_for(price))
      rescue ProcessorAdapter::LookupError
        Result.new(drift: [], error: :unavailable)
      end

      private

      # Errors raise out of the cache block, so a failed lookup is never cached.
      def fetch
        adapter = @plan.processor_adapter
        context = @plan.processor_context
        price = adapter.fetch_price(context:, processor_price_id: @plan.processor_price_id)
        product = adapter.fetch_product(context:, processor_product_id: @plan.processor_product_id) if @plan.processor_product_id.present?
        [price, product]
      end

      def cache_key
        ['billing-snapshot', @plan.platform_id, @plan.id, @plan.processor_price_id, @plan.lock_version]
      end

      # Fields that differ between this plan and the processor's price.
      def drift_for(price)
        return [] if price.nil?

        COMPARED.filter_map do |field, attribute|
          field if price.public_send(attribute) != @plan.public_send(field) && !price.public_send(attribute).nil?
        end
      end
    end
  end
end
