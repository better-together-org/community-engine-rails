# frozen_string_literal: true

module BetterTogether
  module Billing
    # What kind of thing is being sold, as far as tax goes. A category that is not `taxable` is never taxed,
    # whatever the rates are (fresh produce, say). A plan or line item with no category is taxed as standard.
    class TaxCategory < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_tax_categories'

      has_many :tax_rates, class_name: 'BetterTogether::Billing::TaxRate', dependent: :restrict_with_error

      validates :identifier, presence: true, format: { with: /\A[a-z0-9_]+\z/ }, uniqueness: { scope: :platform_id }
      validates :name, presence: true
    end
  end
end
