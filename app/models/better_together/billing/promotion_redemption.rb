# frozen_string_literal: true

module BetterTogether
  module Billing
    # One person using one promotion once, and the credit lot it made. The database allows one per person
    # and promotion, so redeeming twice at the same moment cannot give the credit twice.
    class PromotionRedemption < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_promotion_redemptions'

      belongs_to :promotion, class_name: 'BetterTogether::Billing::Promotion', inverse_of: :redemptions, optional: false
      belongs_to :person, class_name: 'BetterTogether::Person', optional: true
      belongs_to :credit_lot, class_name: 'BetterTogether::Billing::CreditLot', optional: false

      validates :person_id, uniqueness: { scope: :promotion_id }, allow_nil: true

      def readonly? = !new_record?

      private

      def billing_parent = promotion
    end
  end
end
