# frozen_string_literal: true

module BetterTogether
  module Billing
    # Credits a sponsorship's beneficiary via a real Stripe Customer Balance
    # transaction, then records a local audit mirror (MonetaryContribution).
    # Never touches the beneficiary's own subscription directly — Stripe
    # applies the balance credit to the beneficiary's own future invoices.
    class CreditBeneficiaryBalance
      Result = Struct.new(:monetary_contribution, :sponsorship, :already_credited, keyword_init: true)

      # When one_time_payment is given, locks its row for the duration of
      # the already-credited check + Stripe call + insert, so two genuinely
      # concurrent calls for the same payment (a retried request, two
      # browser tabs) can't both pass the check before either has written a
      # row and both credit the beneficiary's Stripe balance for one
      # payment. Mirrors Billing::BenefitCredit#redeem!'s beneficiary.lock!
      # pattern — locked on the payment rather than the beneficiary, since
      # unrelated payments to the same beneficiary shouldn't serialize
      # against each other. Without a one_time_payment there's no natural
      # row to lock or dedupe against, so it always credits (e.g. a manual
      # admin-granted contribution).
      def call(sponsorship:, amount_cents:, currency:, one_time_payment: nil)
        return credit(sponsorship:, amount_cents:, currency:, one_time_payment:) if one_time_payment.blank?

        one_time_payment.with_lock do
          existing = BetterTogether::Billing::MonetaryContribution.find_by(one_time_payment:)
          next Result.new(monetary_contribution: existing, sponsorship:, already_credited: true) if existing

          credit(sponsorship:, amount_cents:, currency:, one_time_payment:)
        end
      end

      private

      def credit(sponsorship:, amount_cents:, currency:, one_time_payment:)
        balance_transaction = create_balance_transaction(sponsorship:, amount_cents:, currency:)

        monetary_contribution = BetterTogether::Billing::MonetaryContribution.create!(
          sponsorship:,
          one_time_payment:,
          amount_cents: amount_cents.abs,
          currency:,
          stripe_balance_transaction_id: balance_transaction.id,
          stripe_payment_intent_id: one_time_payment&.stripe_payment_intent_id
        )

        Result.new(monetary_contribution:, sponsorship:, already_credited: false)
      end

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
