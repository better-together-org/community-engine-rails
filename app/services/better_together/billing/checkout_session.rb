# frozen_string_literal: true

module BetterTogether
  module Billing
    # What ProcessorAdapter#create_checkout_session returns: where to send the buyer (`url`,
    # which must be https), the processor's id for the session (`reference`, kept on the
    # payment as `processor_session_reference` to authorise the buyer's return), and when the
    # session stops being payable (`expires_at`, may be nil). `tax_cents` is the tax the processor will charge on top of the
    # prices, when it says (nil when it does not); core compares it with the order's.
    CheckoutSession = Data.define(:url, :reference, :expires_at, :tax_cents) do
      def initialize(url:, reference:, expires_at: nil, tax_cents: nil) = super
    end
  end
end
