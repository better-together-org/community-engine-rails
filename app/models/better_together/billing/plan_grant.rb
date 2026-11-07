# frozen_string_literal: true

module BetterTogether
  module Billing
    # One thing a plan includes: a role in the platform or a community, access to a gated feature, or an amount of
    # a quota. `kind` comes from an allow-list (see Entitlements::Registry) and `parameters` says which, checked
    # by that kind's handler, so a plan can never name something the platform did not provide for.
    class PlanGrant < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_plan_grants'

      belongs_to :plan, class_name: 'BetterTogether::Billing::Plan', inverse_of: :plan_grants, optional: false

      attr_readonly :plan_id

      before_validation :normalize
      validates :kind, inclusion: { in: ->(_) { Entitlements::Registry.kinds } }
      validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validate :parameters_valid

      # The handler for this grant, ready to apply.
      def handler = Entitlements::Registry.handler_for(self)

      private

      def billing_parent = plan

      def normalize
        self.parameters = parameters.to_h.stringify_keys.transform_values { |value| value.is_a?(String) ? value.strip : value }
      end

      def parameters_valid
        return unless Entitlements::Registry.kinds.include?(kind) && platform

        Entitlements::Registry.handler_class(kind).parameter_errors(parameters, platform:).each { |code| errors.add(:parameters, code) }
      end
    end
  end
end
