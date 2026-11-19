# frozen_string_literal: true

module BetterTogether
  module Billing
    # What a steward still has to do before the platform can sell: billing configured, a payment
    # method switched on, and in-force purchase agreements for each kind of purchase.
    #
    # It is a checklist for people. Checkout does not rely on it: each purchase runs its own
    # AgreementGate, which fails closed on the same facts.
    class Readiness
      Check = Data.define(:key, :ok, :purpose, :detail)

      PURPOSES = %w[subscription one_time].freeze

      def self.call(platform) = new(platform).call

      def initialize(platform)
        @platform = platform
      end

      def call = Result.new(checks:)

      Result = Data.define(:checks) do
        def ready? = checks.all?(&:ok)
        def pending = checks.reject(&:ok)
      end

      private

      attr_reader :platform

      def checks
        [configured, method_enabled, *PURPOSES.map { |purpose| agreements_for(purpose) }]
      end

      def configured = Check.new(key: :configured, ok: Billing.configurable?(platform), purpose: nil, detail: nil)

      def method_enabled
        Check.new(key: :method_enabled, ok: Configuration.processors_for(platform).any?, purpose: nil, detail: nil)
      end

      def agreements_for(purpose)
        gate = Checkout::AgreementGate.new(platform:, purpose:, signer: nil)
        Check.new(key: :agreements, ok: gate.ready?, purpose:, detail: gate.problems.map(&:code).uniq)
      end
    end
  end
end
