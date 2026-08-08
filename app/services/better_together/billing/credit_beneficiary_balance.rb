# frozen_string_literal: true

module BetterTogether
  module Billing
    # Credits a sponsorship's beneficiary via a real Stripe Customer Balance
    # transaction, then records a local audit mirror (MonetaryContribution).
    # Never touches the beneficiary's own subscription directly — Stripe
    # applies the balance credit to the beneficiary's own future invoices.
    class CreditBeneficiaryBalance
      Result = Struct.new(:monetary_contribution, :sponsorship, keyword_init: true)

      def call(sponsorship:, amount_cents:, currency:, one_time_payment: nil)
        balance_transaction = create_balance_transaction(sponsorship:, amount_cents:, currency:)

        monetary_contribution = BetterTogether::Billing::MonetaryContribution.create!(
          sponsorship:,
          one_time_payment:,
          amount_cents: amount_cents.abs,
          currency:,
          stripe_balance_transaction_id: balance_transaction.id,
          stripe_payment_intent_id: one_time_payment&.stripe_payment_intent_id
        )

        Result.new(monetary_contribution:, sponsorship:)
      end

      private

      def create_balance_transaction(sponsorship:, amount_cents:, currency:)
        Stripe::Customer.create_balance_transaction(
          beneficiary_processor_id(sponsorship.beneficiary),
          {
            amount: -amount_cents.abs,
            currency:,
            description: contribution_description(sponsorship)
          }
        )
      end

      # Balance credits require a real Stripe Customer id — force creation via
      # the Pay gem's api_record if the beneficiary hasn't been synced to
      # Stripe yet (e.g. a community that's never subscribed to anything
      # itself but is receiving a sponsor's contribution for the first time).
      def beneficiary_processor_id(beneficiary)
        processor = beneficiary.payment_processor
        processor.api_record unless processor.processor_id?
        processor.processor_id
      end

      def contribution_description(sponsorship)
        sponsor_name = sponsorship.sponsor.try(:name) || sponsorship.sponsor_type
        "Sponsorship contribution from #{sponsor_name}"
      end
    end
  end
end
