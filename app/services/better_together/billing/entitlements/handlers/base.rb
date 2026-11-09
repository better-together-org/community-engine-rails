# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      module Handlers
        # What every kind of grant does. A handler is made for one set of parameters and one platform and:
        #
        # * says whether it makes sense for a beneficiary (`applies_to?`),
        # * names the grant (`key`, stable for the same parameters, so applying twice is one grant),
        # * applies it (`apply`, returning what to record: the thing made or found, whether it is owned, the amount),
        # * and takes it away (`release`), touching only what the entitlement owns.
        #
        # `parameter_errors` is how a plan's parameters are checked, as codes for the plan form.
        class Base
          Applied = Data.define(:record, :owned, :quota_type, :amount) do
            def initialize(record: nil, owned: false, quota_type: nil, amount: 0) = super
          end

          def self.parameter_errors(_parameters, platform:) = raise(NotImplementedError, "#{name}.parameter_errors")

          def initialize(parameters, platform:)
            @parameters = parameters.to_h.stringify_keys
            @platform = platform
          end

          attr_reader :parameters, :platform

          def kind = raise(NotImplementedError, "#{self.class}#kind")
          def key = raise(NotImplementedError, "#{self.class}#key")
          def applies_to?(_beneficiary) = raise(NotImplementedError, "#{self.class}#applies_to?")
          def apply(_entitlement) = raise(NotImplementedError, "#{self.class}#apply")
          def release(_grant) = raise(NotImplementedError, "#{self.class}#release")
        end
      end
    end
  end
end
