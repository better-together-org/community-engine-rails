# frozen_string_literal: true

module BetterTogether
  module Billing
    # Resolves whether a holder currently has a given entitlement, dispatched
    # by the entitlement's registered resolution mode — :grant checks
    # Billing::Entitlement rows, :credit checks Billing::BenefitCredit's
    # available balance. Mirrors HostedEntitlementResolver's Result-struct
    # shape, but is generic across any registered entitlement_key rather
    # than hardcoded to hosted-community access.
    class EntitlementResolver
      Result = Struct.new(
        :holder,
        :entitlement_key,
        :entitled,
        :resolution,
        :entitlements,
        :credit_balance,
        keyword_init: true
      ) do
        def entitled?
          !!entitled
        end
      end

      class << self
        def call(holder:, entitlement_key:)
          new(holder:, entitlement_key:).call
        end
      end

      def initialize(holder:, entitlement_key:)
        @holder = holder
        @entitlement_key = entitlement_key.to_s
      end

      def call
        registry_entry.fetch(:resolution) == 'credit' ? resolve_via_credit : resolve_via_grant
      end

      private

      attr_reader :holder, :entitlement_key

      def registry_entry
        BetterTogether::EntitlementRegistry.fetch(entitlement_key)
      end

      def resolve_via_grant
        grants = BetterTogether::Billing::Entitlement.current.for_holder_and_key(holder, entitlement_key)

        Result.new(holder:, entitlement_key:, entitled: grants.exists?, resolution: 'grant', entitlements: grants.to_a)
      end

      def resolve_via_credit
        balance = BetterTogether::Billing::BenefitCredit.available_balance(holder, entitlement_key)

        Result.new(holder:, entitlement_key:, entitled: balance.positive?, resolution: 'credit', credit_balance: balance)
      end
    end
  end
end
