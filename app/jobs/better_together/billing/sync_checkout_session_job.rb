# frozen_string_literal: true

module BetterTogether
  module Billing
    # Async counterpart to the synchronous checkout-session sync that used to
    # run inline in Billing::ControllerConcern#show on the browser's return-
    # from-Stripe leg. The webhook-driven sync (StripeEventProcessor) remains
    # the authoritative trigger and fires even if the payer never lands back
    # on the billing page — this job only provides best-effort, near-
    # immediate feedback for the page that's actively watching, pushed via
    # CheckoutSessionSyncBroadcaster instead of blocking the request.
    class SyncCheckoutSessionJob < BetterTogether::ApplicationJob
      queue_as :default

      retry_on StandardError, wait: :polynomially_longer, attempts: 10

      def perform(checkout_session_id, billable_owner_type, billable_owner_id)
        billable_owner = OwnershipResolver.resolve_record(billable_owner_type, billable_owner_id)
        return unless billable_owner

        result = BetterTogether::Billing::StripeCheckoutSessionSync.new.call(
          checkout_session_id:, beneficiary: billable_owner
        )
        broadcaster.call(checkout_session_id:, result:)
      rescue Stripe::InvalidRequestError => e
        # Not retried via retry_on — a session ID Stripe rejects outright will
        # never succeed on retry, unlike a transient StandardError.
        broadcaster.call(checkout_session_id:, error: e)
      end

      private

      def broadcaster
        @broadcaster ||= BetterTogether::Billing::CheckoutSessionSyncBroadcaster.new
      end
    end
  end
end
