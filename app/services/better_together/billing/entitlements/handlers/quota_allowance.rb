# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      module Handlers
        # An amount of a quota (media storage bytes, AI translation tokens) on top of the type's default.
        #
        #   { "quota_type": "media_storage", "amount": 5368709120 }
        #
        # There is no record behind it: the amount is kept on the entitlement grant, and
        # Entitlements::QuotaAllowances (registered with Quotas::Allowances) adds the live ones up. After every
        # change the quota's stored limit is brought in line (`Quotas.sync_limit!`). Usage is never reduced: when
        # an allowance goes, the limit drops and only NEW consumption is refused, if enforcement is on.
        class QuotaAllowance < Base
          def self.parameter_errors(parameters, platform:) = new(parameters, platform:).errors

          def errors
            list = []
            list << :quota_unknown unless BetterTogether::Quotas::Type.keys.include?(parameters['quota_type'].to_s)
            list << :amount_invalid unless amount.positive?
            list
          end

          def kind = 'quota_allowance'

          def key = "quota_allowance:#{parameters['quota_type']}"

          # Persons, communities and the platform itself are the quota owners.
          def applies_to?(beneficiary) = beneficiary.is_a?(BetterTogether::Quotas::Owner) && errors.empty?

          def apply(_entitlement)
            Applied.new(owned: true, quota_type: parameters['quota_type'].to_s, amount:)
          end

          def release(_grant) = nil

          # Called after the grant row changes, so the stored limit follows.
          def self.sync(beneficiary, quota_type)
            BetterTogether::Quotas.sync_limit!(type: quota_type, owner: beneficiary)
          end

          private

          def amount
            Integer(parameters['amount'], exception: false).to_i
          end
        end
      end
    end
  end
end
