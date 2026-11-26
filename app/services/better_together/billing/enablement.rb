# frozen_string_literal: true

module BetterTogether
  module Billing
    # Why billing is not on for a platform, in the order a steward fixes things. Billing is on only when
    # the host switched it on, set its organisation details, the platform may bill, and one payment method
    # is enabled. Used by the page a steward sees in place of a bare 404.
    class Enablement
      Problem = Data.define(:key, :detail)

      def self.call(platform) = new(platform).problems

      def initialize(platform)
        @platform = platform
      end

      def problems
        [flag, identity, hosted, method_enabled].compact
      end

      private

      attr_reader :platform

      def flag = (Problem.new(key: :flag, detail: []) unless Configuration.requested?)

      def identity
        missing = Configuration.missing_keys
        Problem.new(key: :identity, detail: missing) if missing.any?
      end

      def hosted = (Problem.new(key: :hosted, detail: []) unless HostedBilling.permits?(platform, :billing))

      def method_enabled
        return if Configuration.processors_for(platform).any?

        Problem.new(key: :method_enabled, detail: [])
      end
    end
  end
end
