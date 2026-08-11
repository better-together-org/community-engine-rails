# frozen_string_literal: true

module BetterTogether
  module Billing
    # Resolves the sponsorship beneficiary from a synced one-time payment's
    # checkout-session metadata and credits its balance. Shared between
    # StripeEventProcessor (the authoritative webhook leg — fires even if the
    # payer never returns to the success URL) and CommunityBillingsController
    # (the browser-return leg — gives immediate UI feedback when it does).
    # Safe to call from both: CreditBeneficiaryBalance locks the
    # one_time_payment row internally, so whichever leg runs first wins and
    # the other is a no-op.
    class ProcessSponsorshipContribution
      Result = Struct.new(:credit_result, :beneficiary, keyword_init: true)

      def call(one_time_payment:, checkout_session:)
        return if one_time_payment.blank?

        beneficiary = resolved_beneficiary(checkout_session)
        return if beneficiary.blank?

        sponsorship = find_or_create_active_sponsorship(sponsor: one_time_payment.owner, beneficiary:)
        credit_result = BetterTogether::Billing::CreditBeneficiaryBalance.new.call(
          sponsorship:,
          amount_cents: one_time_payment.amount_cents,
          currency: one_time_payment.currency,
          one_time_payment:
        )

        Result.new(credit_result:, beneficiary:)
      end

      private

      def resolved_beneficiary(checkout_session)
        metadata = checkout_session.metadata.to_h
        BetterTogether::Billing::OwnershipResolver.resolve_record(
          metadata['bt_sponsorship_beneficiary_type'],
          metadata['bt_sponsorship_beneficiary_id']
        )
      end

      def find_or_create_active_sponsorship(sponsor:, beneficiary:)
        BetterTogether::Billing::Sponsorship.status_active
                                            .for_sponsor(sponsor)
                                            .for_beneficiary(beneficiary)
                                            .first ||
          BetterTogether::Billing::Sponsorship.create!(sponsor:, beneficiary:, status: 'active', accepted_at: Time.current)
      end
    end
  end
end
