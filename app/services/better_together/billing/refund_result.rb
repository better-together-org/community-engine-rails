# frozen_string_literal: true

module BetterTogether
  module Billing
    # What ProcessorAdapter#refund returns: the processor's id for the refund (`reference`, kept as the
    # refund's `processor_reference`, which is what makes a later `refund.updated` or `charge.refunded`
    # event find the refund core already recorded), its `status` (`succeeded`, `pending` or `failed`,
    # as Billing::Refund statuses) and the amount refunded.
    RefundResult = Data.define(:reference, :status, :amount_cents)
  end
end
