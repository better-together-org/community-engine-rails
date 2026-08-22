# frozen_string_literal: true

module BetterTogether
  module Billing
    # Sponsorship-contribution crediting side effect of a successful checkout-
    # session sync — extracted from CommunityBillingsController's synchronous
    # load_billing_overview_extras override so CheckoutSessionSyncBroadcaster
    # can invoke it from the async SyncCheckoutSessionJob. Only fires for a
    # one-time-payment sync result (the recurring-subscription sync path has
    # no analogous side effect); ProcessSponsorshipContribution itself no-ops
    # when there's no one_time_payment, so this stays a thin pass-through.
    class ProcessSponsorshipContributionFromCheckoutSync
      Result = Struct.new(:credited, :already_credited, :beneficiary, :error, keyword_init: true)

      def call(sync_result)
        return unless sync_result&.one_time_payment.present?

        service_result = BetterTogether::Billing::ProcessSponsorshipContribution.new.call(
          one_time_payment: sync_result.one_time_payment, checkout_session: sync_result.checkout_session
        )
        build_result(service_result)
      rescue ActiveRecord::RecordInvalid, Stripe::StripeError => e
        Result.new(credited: false, error: e)
      end

      private

      def build_result(service_result)
        return if service_result.blank?

        Result.new(
          credited: true,
          already_credited: service_result.credit_result.already_credited,
          beneficiary: service_result.beneficiary
        )
      end
    end
  end
end
