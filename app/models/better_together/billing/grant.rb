# frozen_string_literal: true

module BetterTogether
  module Billing
    # One thing a plan includes: a role in the platform or a community, access to a gated feature, or an amount of
    # a quota. `kind` comes from an allow-list (see Entitlements::Registry) and `parameters` says which, checked
    # by that kind's handler, so a plan can never name something the platform did not provide for.
    class Grant < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_grants'

      # What it is part of: a product, which may be a plan.
      belongs_to :product, class_name: 'BetterTogether::Billing::Product', inverse_of: :grants, optional: false

      attr_readonly :product_id

      before_validation :normalize
      validates :kind, inclusion: { in: ->(_) { Entitlements::Registry.kinds } }
      validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validate :parameters_valid
      validate :not_already_on_the_plan

      # The handler for this grant, ready to apply.
      def handler = Entitlements::Registry.handler_for(self)

      # The product (a plan is one) this is part of.
      def owner = product

      def plan = (product if product.is_a?(Plan))

      def plan=(record)
        self.product = record
      end

      private

      def billing_parent = owner

      def normalize
        self.parameters = parameters.to_h.stringify_keys.transform_values { |value| value.is_a?(String) ? value.strip : value }
      end

      # One grant per thing (the same role, feature or quota once): to change an amount, edit it.
      def not_already_on_the_plan # rubocop:disable Metrics/AbcSize
        return unless owner && Entitlements::Registry.kinds.include?(kind) && parameters_errors.empty?

        key = handler.key
        taken = owner.included_grants.where.not(id: id).any? { |other| other.kind == kind && other.handler.key == key }
        errors.add(:parameters, :already_on_the_plan) if taken
      end

      def parameters_errors
        Entitlements::Registry.handler_class(kind).parameter_errors(parameters, platform:)
      end

      def parameters_valid
        return unless Entitlements::Registry.kinds.include?(kind) && platform

        Entitlements::Registry.handler_class(kind).parameter_errors(parameters, platform:).each { |code| errors.add(:parameters, code) }
      end
    end
  end
end
