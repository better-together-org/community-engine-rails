# frozen_string_literal: true

module BetterTogether
  module Billing
    # One tax in one zone: its label (GST, PST, VAT), its rate as a fraction (0.05 is five percent), and when it
    # applies. A rate with no category applies to every taxable category. A rate is discarded, never deleted, so
    # the tax lines of past orders keep pointing at it.
    class TaxRate < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_tax_rates'

      belongs_to :tax_zone, class_name: 'BetterTogether::Billing::TaxZone', optional: false
      belongs_to :tax_category, class_name: 'BetterTogether::Billing::TaxCategory', optional: true

      validates :label, presence: true
      validates :rate, numericality: { greater_than_or_equal_to: 0, less_than: 1 }
      validate :zone_and_category_on_this_platform
      validate :ends_after_it_starts

      scope :kept, -> { where(discarded_at: nil) }
      scope :active_at, lambda { |time|
        kept.where(arel_table[:starts_at].eq(nil).or(arel_table[:starts_at].lteq(time)))
            .where(arel_table[:ends_at].eq(nil).or(arel_table[:ends_at].gt(time)))
      }

      def discard! = update!(discarded_at: Time.current)

      def applies_to?(category) = tax_category_id.nil? || tax_category_id == category&.id

      private

      def zone_and_category_on_this_platform
        errors.add(:tax_zone, :platform_owner_mismatch) if tax_zone && tax_zone.platform_id != platform_id
        errors.add(:tax_category, :platform_owner_mismatch) if tax_category && tax_category.platform_id != platform_id
      end

      def ends_after_it_starts
        errors.add(:ends_at, :invalid) if starts_at && ends_at && ends_at <= starts_at
      end
    end
  end
end
