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

      # An installed method that does not go through a vendor (settlement manual or
      # internal), like cash. False for an unknown name or an adapter that fails the contract.
      def offline_method?(name)
        return false unless processor_names.map(&:to_s).include?(name.to_s)

        processor_adapter(name)&.settlement_kind != :remote
      rescue ProcessorAdapter::ContractError
        false
      end

      # The methods core ships, registered once at boot. They are available to every
      # platform but work for a seller only after a steward enables them
      # (see ProcessorSetting).
      def register_builtin_processors!
        builtin_processors.each { |name, adapter_class| register_processor(name, -> { adapter_class.new }) }
      end

      # Registers any built-in method that is not installed yet (it never replaces one that is).
      def ensure_builtin_processors!
        missing = builtin_processors.except(*processor_names)
        missing.each { |name, adapter_class| register_processor(name, -> { adapter_class.new }) }
      end

      # Name => adapter class, for the methods core ships. A method so classes load lazily.
      def builtin_processors
        { cash: Processors::Cash, cheque: Processors::Cheque, etransfer: Processors::ETransfer }
      end

      # Whether a steward can configure billing for a platform: the host switched it on and
      # configured an identity, and at least one method is installed. Unlike #enabled?,
      # this does not need a method to be enabled already, so the settings page can be
      # reached to enable the first one.
      def configurable?(platform = Current.platform, env: ENV)
        platform.present? && Configuration.requested?(env) && Configuration.ready?(env) && processor_names.any?
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
