# frozen_string_literal: true

module BetterTogether
  module Billing
    # Asks a record's processor to hold it (a Plan, or a Product with its prices) and returns what the processor did as a
    # CatalogSyncResult. The adapter never writes the record: the caller stores the result.
    #
    # An adapter at contract version 2 is given the whole CatalogItem (`sync_catalog_item`). A version 1 adapter only knows
    # `sync_plan`, so a plan goes to it that way and its single price is wrapped; it cannot hold a product, which is then sent
    # inline at checkout instead (Checkout::Lines).
    class CatalogSync
      class NotConfigured < StandardError; end
      class Unsupported < StandardError; end

      def self.call(...) = new(...).call

      def initialize(record)
        @record = record
      end

      def call
        raise NotConfigured, 'no billing configuration for this record' unless context && adapter&.supports?(:plan_sync)

        adapter.catalog_aware? ? push_item : push_plan
      end

      private

      attr_reader :record

      def adapter = record.processor_adapter
      def context = record.processor_context
      def key = record.sync_idempotency_key

      def push_item
        result = adapter.sync_catalog_item(context:, item: CatalogItem.for(record), idempotency_key: key)
        raise TypeError, "#{adapter.class}#sync_catalog_item must return CatalogSyncResult" unless result.is_a?(CatalogSyncResult)

        result
      end

      # Contract version 1: `sync_plan` for a plan.
      def push_plan
        guard_plan!
        result = plan_sync_result

        CatalogSyncResult.new(product_id: result.product_id, prices: [result.price.with(ref: record.current_price.id)])
      end

      def plan_sync_result
        adapter.sync_plan(context:, plan: record, idempotency_key: key).tap do |result|
          raise TypeError, "#{adapter.class}#sync_plan must return PlanSyncResult" unless result.is_a?(PlanSyncResult)
        end
      end

      def guard_plan!
        return if record.is_a?(Plan)

        raise Unsupported, "#{adapter.class} implements contract #{adapter.contract_version} and cannot hold a product"
      end
    end
  end
end
