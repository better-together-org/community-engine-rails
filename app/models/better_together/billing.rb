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

      # Builds the named (or first registered) adapter and checks its contract
      # version and that it reports the name it was registered under.
      def processor_adapter(name = nil)
        entry = BetterTogether.adapter_for(ADAPTER_GROUP, name)
        return if entry.blank?

        ProcessorAdapter.verify!(entry[:adapter].call, name: entry[:name])
      end

      # Billing is on for a platform only with the host's flag, a configured
      # identity, and a registered processor that has a context for that platform.
      # With no platform (a job or console with no tenant in hand) it is off.
      def enabled?(platform = Current.platform, env: ENV)
        platform.present? &&
          Configuration.requested?(env) &&
          Configuration.ready?(env) &&
          Configuration.processors_for(platform).any?
      end
    end
  end
end
