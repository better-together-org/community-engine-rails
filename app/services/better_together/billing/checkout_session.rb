# frozen_string_literal: true

module BetterTogether
  module Billing
    # What ProcessorAdapter#create_checkout_session returns: where to send the buyer (`url`,
    # which must be https), the processor's id for the session (`reference`, kept on the
    # payment as `processor_session_reference` to authorise the buyer's return), and when the
    # session stops being payable (`expires_at`, may be nil).
    CheckoutSession = Data.define(:url, :reference, :expires_at) do
      def initialize(url:, reference:, expires_at: nil) = super
    end
  end
end
