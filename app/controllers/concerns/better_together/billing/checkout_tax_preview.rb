# frozen_string_literal: true

module BetterTogether
  module Billing
    # The tax a buyer sees at checkout, for the billing address they picked (or the first offered).
    # Needs @plan, @addresses, @selected_address_id and @parts from the including controller.
    module CheckoutTaxPreview
      private

      def load_tax_preview
        @tax_preview = tax_preview_for(@addresses.find { |address| address.id == @selected_address_id } || @addresses.first)
      end

      def tax_preview_for(address) = Checkout::TaxPreview.new(platform: billing_owner, plan: @plan, address:)

      # Parts that cover the whole total, tax included, are not parts.
      def parts_too_large?
        picked = current_user.person.addresses.find_by(id: params[:billing_address_id])
        @parts.any? && parts_cents >= tax_preview_for(picked).total_cents
      end
    end
  end
end
