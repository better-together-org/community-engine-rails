# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Sponsorship do
  subject(:sponsorship) { described_class.new(sponsor:, beneficiary:, status: 'active') }

  let(:sponsor) { create(:better_together_person) }
  let(:beneficiary) { create(:better_together_community) }

  around do |example|
    original = ENV.fetch('BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED', nil)
    ENV['BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED'] = 'false'
    example.run
  ensure
    ENV['BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED'] = original
  end

  it 'is valid with a sponsor, beneficiary, and status when consent is not enforced' do
    expect(sponsorship).to be_valid
  end

  it 'generates a secure token on save' do
    sponsorship.save!

    expect(sponsorship.token).to be_present
  end

  it 'rejects a sponsor type that does not include Billing::Billable' do
    sponsorship.sponsor = build(:better_together_billing_plan)

    expect(sponsorship).not_to be_valid
    expect(sponsorship.errors[:sponsor_type]).to be_present
  end

  it 'rejects a beneficiary type that does not include Billing::SponsorshipRecipient' do
    sponsorship.beneficiary = build(:better_together_billing_plan)

    expect(sponsorship).not_to be_valid
    expect(sponsorship.errors[:beneficiary_type]).to be_present
  end

  describe 'consent enforcement' do
    around do |example|
      original = ENV.fetch('BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED', nil)
      ENV['BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED'] = 'true'
      example.run
    ensure
      ENV['BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED'] = original
    end

    it 'rejects a beneficiary that has not opted in when consent is enforced' do
      expect(described_class.consent_enforced?).to be(true)
      expect(sponsorship).not_to be_valid
      expect(sponsorship.errors[:beneficiary]).to be_present
    end

    it 'allows a beneficiary that has opted in' do
      beneficiary.update!(accepts_sponsorship: true)

      expect(sponsorship).to be_valid
    end
  end

  describe '#accept!' do
    it 'transitions to accepted and stamps accepted_at' do
      sponsorship.update!(status: 'pending')

      sponsorship.accept!

      expect(sponsorship).to be_status_accepted
      expect(sponsorship.accepted_at).to be_present
    end
  end

  describe '#decline!' do
    it 'transitions to declined and stamps declined_at with a reason' do
      sponsorship.update!(status: 'pending')

      sponsorship.decline!(reason: 'not needed right now')

      expect(sponsorship).to be_status_declined
      expect(sponsorship.declined_at).to be_present
      expect(sponsorship.cancellation_reason).to eq('not needed right now')
    end
  end

  describe '#end!' do
    it 'transitions an active sponsorship to ended — the real "unsponsor" action' do
      sponsorship.save!

      sponsorship.end!(reason: 'sponsor withdrew support')

      expect(sponsorship).to be_status_ended
      expect(sponsorship.ended_at).to be_present
      expect(sponsorship.cancellation_reason).to eq('sponsor withdrew support')
    end
  end

  describe 'multiple simultaneous sponsorships for the same beneficiary' do
    it 'allows two different sponsors to have active sponsorships for one beneficiary at once' do
      other_sponsor = create(:better_together_person)
      sponsorship.save!
      other_sponsorship = described_class.create!(sponsor: other_sponsor, beneficiary:, status: 'active')

      expect(described_class.status_active.for_beneficiary(beneficiary).count).to eq(2)
      expect(other_sponsorship).to be_persisted
    end
  end
end
