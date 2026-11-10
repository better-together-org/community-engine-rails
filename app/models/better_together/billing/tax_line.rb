# frozen_string_literal: true

module BetterTogether
  module Billing
    # One tax charged on one line of an order. It copies the label and rate when the order was placed, so
    # changing a rate later never changes an order that already exists. `included` means the amount is part
    # of the price, not added to it.
    class TaxLine < ApplicationRecord
      include PlatformBound
      include ParentBound
      include EncryptedAttributes
      include Translatable
      include LocalizedSnapshot

      self.table_name = 'better_together_billing_tax_lines'

      # The number of whoever collected this tax, as it was when the order was placed.
      encrypts_billing_attribute :registration_number

      # The tax's name in every language, as it was when the order was made.
      translates :label, type: :string

      belongs_to :order, class_name: 'BetterTogether::Billing::Order', inverse_of: :tax_lines, optional: false
      belongs_to :line_item, class_name: 'BetterTogether::Billing::LineItem', inverse_of: :tax_lines, optional: false
      belongs_to :tax_rate, class_name: 'BetterTogether::Billing::TaxRate', optional: true

      validates :authority, inclusion: { in: TaxRate::AUTHORITIES }
      validates :label, presence: true
      validates :rate, numericality: { greater_than_or_equal_to: 0 }
      validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      private

      def billing_parent = order
    end
  end
end
