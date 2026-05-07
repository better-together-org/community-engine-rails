# frozen_string_literal: true

module BetterTogether
  module Billing
    # Catalog entry for a billable Community Engine plan.
    class Plan < ApplicationRecord
      self.table_name = 'better_together_billing_plans'

      BILLING_INTERVALS = %w[month year one_time].freeze
      DEFAULT_ELIGIBLE_OWNER_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze

      has_many :subscriptions,
               class_name: 'BetterTogether::Billing::Subscription',
               foreign_key: :billing_plan_id,
               dependent: :restrict_with_exception,
               inverse_of: :billing_plan

      validates :identifier, :name, :currency, :stripe_price_id, presence: true
      validates :identifier, uniqueness: true
      validates :amount_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
      validates :billing_interval, inclusion: { in: BILLING_INTERVALS }
      validates :currency, length: { is: 3 }
      validates :active, inclusion: { in: [true, false] }

      scope :active, -> { where(active: true) }

      def recurring?
        billing_interval.in?(%w[month year])
      end

      def eligible_for?(billable_owner)
        return false unless billable_owner.present?

        eligible_billable_owner_types.include?(billable_owner.class.name)
      end

      def eligible_billable_owner_types
        raw_types = Array(metadata['eligible_billable_owner_types']).presence || DEFAULT_ELIGIBLE_OWNER_TYPES

        raw_types.filter_map { |type_name| OwnershipResolver.supported_owner_type_name(type_name) }.presence || DEFAULT_ELIGIBLE_OWNER_TYPES
      end
    end
  end
end
