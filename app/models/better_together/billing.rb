# frozen_string_literal: true

module BetterTogether
  # Vendor-neutral billing domain. Payment processors plug in as adapters
  # (see Billing::ProcessorAdapter); with none registered, billing stays off.
  module Billing
    ADAPTER_GROUP = :billing_processor

    class << self
      def register_processor(name, factory = nil, &block)
        BetterTogether.register_adapter(ADAPTER_GROUP, name, factory || block)
      end

      def processor_names
        BetterTogether.adapters_for(ADAPTER_GROUP).filter_map { |entry| entry[:name]&.to_sym }
      end

      # Builds the named (or first registered) adapter and checks its contract version.
      def processor_adapter(name = nil)
        entry = BetterTogether.adapter_for(ADAPTER_GROUP, name)
        return if entry.blank?

        ProcessorAdapter.verify!(entry[:adapter].call)
      end

      def enabled?(env = ENV)
        ActiveModel::Type::Boolean.new.cast(env['BT_BILLING_ENABLED']) == true &&
          Configuration.ready?(env) && processor_names.any?
      end
    end
  end
end
