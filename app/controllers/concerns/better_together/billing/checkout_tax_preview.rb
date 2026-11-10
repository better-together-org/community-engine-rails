# frozen_string_literal: true

module BetterTogether
  module Billing
    # The tax a buyer sees at checkout, for the billing address they picked (or the first offered). A new address
    # typed in has no place until it is saved, so no tax is promised for it; the order carries it once placed.
    # Needs @plan, @addresses, @selected_address_id and @parts from the including controller.
    module CheckoutTaxPreview
      private

      def load_tax_preview
        @tax_preview = tax_preview_for(preview_address)
      end

      def preview_address
        return if @selected_address_id == 'new'

        @addresses.find { |address| address.id == @selected_address_id } || @addresses.first
      end

      def tax_preview_for(address) = Checkout::TaxPreview.new(platform: billing_owner, plan: @plan, address:)

      # Parts that cover the whole total, tax included, are not parts. Judged on the address the order will carry (the
      # one chosen or just saved), so tax on a newly entered address counts.
      def parts_too_large?
        @parts.any? && parts_cents >= tax_preview_for(@address).total_cents
      end
    end
  end
end
