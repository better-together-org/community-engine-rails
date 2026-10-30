# frozen_string_literal: true

module BetterTogether
  module Billing
    # One thing on an order. It copies what the purchasable was called and cost when the order was
    # placed, so changing a plan later never changes an order that already exists.
    class OrderLine < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_order_lines'

      belongs_to :order, class_name: 'BetterTogether::Billing::Order', inverse_of: :lines, optional: false
      belongs_to :purchasable, polymorphic: true, optional: true

      validates :description, presence: true
      validates :quantity, numericality: { only_integer: true, greater_than: 0 }
      validates :unit_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :currency, inclusion: { in: Plan::SUPPORTED_CURRENCY_CODES }
      validates :purchasable_id, presence: true
      validate :purchasable_registered

      def total_cents = quantity.to_i * unit_amount_cents.to_i

      private

      def billing_parent = order

      # Never load a purchasable whose type is not on the allow-list.
      def purchasable_registered
        return if Purchasable.model_names.include?(purchasable_type)

        errors.add(:purchasable_type, :inclusion)
      end
    end
  end
end
