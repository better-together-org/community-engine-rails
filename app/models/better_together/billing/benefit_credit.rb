# frozen_string_literal: true

module BetterTogether
  module Billing
    # Append-only ledger of non-monetary benefit grants/redemptions (e.g. "3
    # event registration credits"). Unlike MonetaryContribution, there is no
    # external system of record for this — Stripe has no concept of it — so
    # the available balance is always computed as SUM(quantity) across every
    # row for a beneficiary+benefit_key, never stored in a mutable counter.
    # Positive quantity = grant, negative quantity = redemption.
    class BenefitCredit < ApplicationRecord
      self.table_name = 'better_together_billing_benefit_credits'

      class InsufficientBalanceError < StandardError; end

      belongs_to :beneficiary, polymorphic: true
      belongs_to :sponsor, polymorphic: true, optional: true
      belongs_to :sponsorship,
                 class_name: 'BetterTogether::Billing::Sponsorship',
                 optional: true
      belongs_to :related_record, polymorphic: true, optional: true

      validates :benefit_key, inclusion: { in: -> { BetterTogether::BenefitRegistry.keys } }
      validates :quantity, numericality: { other_than: 0, only_integer: true }
      validates :beneficiary_type,
                inclusion: { in: -> { BetterTogether::Billing::SponsorshipRecipient.included_in_models.map(&:name) } }
      validates :sponsor_type,
                inclusion: { in: -> { BetterTogether::Billing::Billable.included_in_models.map(&:name) } },
                allow_nil: true

      scope :for_benefit, ->(beneficiary, benefit_key) { where(beneficiary:, benefit_key:) }

      class << self
        def available_balance(beneficiary, benefit_key)
          for_benefit(beneficiary, benefit_key).sum(:quantity)
        end

        # Grants credits — always a positive addition to the ledger. sponsor/
        # sponsorship are optional: a blank sponsor means self- or
        # admin-granted, not funded by a standing Sponsorship relationship.
        # rubocop:disable Metrics/ParameterLists -- all 6 are meaningful, independent ledger-entry attributes
        def grant!(beneficiary:, benefit_key:, quantity:, sponsor: nil, sponsorship: nil, related_record: nil)
          raise ArgumentError, 'quantity must be positive' unless quantity.positive?

          create!(beneficiary:, benefit_key:, quantity:, sponsor:, sponsorship:, related_record:)
        end
        # rubocop:enable Metrics/ParameterLists

        # Redeems credits — always a negative addition to the ledger. Locks
        # the beneficiary row for the duration of the balance check + insert
        # so two concurrent redemptions against the same balance can't both
        # read a sufficient balance and both succeed when only one should.
        def redeem!(beneficiary:, benefit_key:, quantity:, related_record: nil)
          raise ArgumentError, 'quantity must be positive' unless quantity.positive?

          transaction do
            beneficiary.lock!
            current_balance = available_balance(beneficiary, benefit_key)
            raise InsufficientBalanceError, "insufficient #{benefit_key} balance" if current_balance < quantity

            create!(beneficiary:, benefit_key:, quantity: -quantity, related_record:)
          end
        end
      end
    end
  end
end
