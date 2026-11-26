# frozen_string_literal: true

module BetterTogether
  module Billing
    # Asks a record's processor to hold it (a product, or a plan, with its prices) and returns what the processor did as a
    # CatalogSyncResult. The adapter never writes the record: the caller stores the result.
    class CatalogSync
      class NotConfigured < StandardError; end

      def self.call(...) = new(...).call

      def initialize(record)
        @record = record
      end

      def call
        raise NotConfigured, 'no billing configuration for this record' unless context && adapter&.supports?(:catalog_sync)

        push_item
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
    end
  end
end
