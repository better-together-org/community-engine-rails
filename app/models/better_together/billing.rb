# frozen_string_literal: true

module BetterTogether
  # Vendor-neutral billing domain. Payment processors plug in as adapters
  # (see Billing::ProcessorAdapter); with none registered, billing stays off.
  module Billing
    ADAPTER_GROUP = :billing_processor

    class << self
      # The language a platform's own copy is in when nothing narrower applies. Platforms have no language of
      # their own yet, so it is the app default; the platform is passed so one can be read here later.
      def platform_locale(_platform = nil) = I18n.default_locale

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

      # An installed method Community Engine settles itself, with no vendor: manual (cash, a
      # cheque, an e-transfer) or internal (store credit). False for an unknown name or an
      # adapter that fails the contract.
      def local_method?(name) = settlement_kind_of(name).then { |kind| !kind.nil? && kind != :remote }

      # An installed method the seller confirms by hand (cash, a cheque, an e-transfer). These,
      # and only these, have instructions, an acknowledgement and an offline payment to confirm.
      def manual_method?(name) = settlement_kind_of(name) == :manual

      # An installed method that is a ledger inside Community Engine (store credit).
      def internal_method?(name) = settlement_kind_of(name) == :internal

      # The settlement kind of an installed method, or nil for an unknown name or an adapter
      # that fails the contract.
      def settlement_kind_of(name)
        return unless processor_names.map(&:to_s).include?(name.to_s)

        processor_adapter(name)&.settlement_kind
      rescue ProcessorAdapter::ContractError
        nil
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
        { cash: Processors::Cash, cheque: Processors::Cheque, etransfer: Processors::ETransfer, store_credit: Processors::StoreCredit }
      end

      # Whether a steward can configure billing for a platform: the host switched it on and
      # configured an identity, and at least one method is installed. Unlike #enabled?,
      # this does not need a method to be enabled already, so the settings page can be
      # reached to enable the first one.
      def configurable?(platform = Current.platform, env: ENV)
        platform.present? && platform.host? && Configuration.requested?(env) && Configuration.ready?(env) && processor_names.any?
      end

      # Billing is on for a platform only with the host's flag, a configured
      # identity, and a registered processor that has a context for that platform.
      # With no platform (a job or console with no tenant in hand) it is off.
      # Answers for the real ENV are remembered per platform for the request or job.
      def enabled?(platform = Current.platform, env: ENV)
        return compute_enabled?(platform, env) unless env.equal?(ENV) && platform.respond_to?(:id)

        memo = (Current.billing_enabled ||= {})
        return memo[platform.id] if memo.key?(platform.id)

        memo[platform.id] = compute_enabled?(platform, env)
      end

      def compute_enabled?(platform, env)
        platform.present? &&
          Configuration.requested?(env) &&
          Configuration.ready?(env) &&
          Configuration.processors_for(platform).any?
      end
    end
  end
end
