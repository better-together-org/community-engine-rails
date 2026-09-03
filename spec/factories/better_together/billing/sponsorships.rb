# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/sponsorship',
          class: 'BetterTogether::Billing::Sponsorship',
          aliases: %i[better_together_billing_sponsorship] do
    association :sponsor, factory: :better_together_person
    association :beneficiary, factory: :better_together_community
    status { 'active' }

    # Consent is enforced by default (BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED);
    # a factory-built sponsorship represents an already-valid relationship, so
    # its beneficiary must already have opted in.
    after(:build) do |sponsorship|
      next unless sponsorship.beneficiary.respond_to?(:accepts_sponsorship=)

      sponsorship.beneficiary.accepts_sponsorship = true
      sponsorship.beneficiary.save! if sponsorship.beneficiary.persisted?
    end
  end
end
