# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EntitlementResolver do
  let(:holder) { create(:better_together_community) }

  describe 'resolution: grant' do
    it 'is entitled when a current Billing::Entitlement row exists' do
      BetterTogether::Billing::Entitlement.grant!(holder:, entitlement_key: 'hosted_access')

      result = described_class.call(holder:, entitlement_key: 'hosted_access')

      expect(result).to be_entitled
      expect(result.resolution).to eq('grant')
      expect(result.entitlements).to be_present
    end

    it 'is not entitled when no Billing::Entitlement row exists' do
      result = described_class.call(holder:, entitlement_key: 'hosted_access')

      expect(result).not_to be_entitled
      expect(result.entitlements).to eq([])
    end

    it 'is not entitled once the grant has been revoked' do
      BetterTogether::Billing::Entitlement.grant!(holder:, entitlement_key: 'hosted_access')
      BetterTogether::Billing::Entitlement.revoke!(holder:, entitlement_key: 'hosted_access')

      result = described_class.call(holder:, entitlement_key: 'hosted_access')

      expect(result).not_to be_entitled
    end

    it 'is not entitled once the grant has expired' do
      BetterTogether::Billing::Entitlement.grant!(holder:, entitlement_key: 'hosted_access', expires_at: 1.day.ago)

      result = described_class.call(holder:, entitlement_key: 'hosted_access')

      expect(result).not_to be_entitled
    end
  end

  describe 'resolution: credit' do
    before do
      allow(BetterTogether::EntitlementRegistry).to receive(:fetch).with('event_registration').and_return(
        key: 'event_registration', name: 'Event Registration', resolution: 'credit'
      )
    end

    it 'is entitled when the holder has a positive BenefitCredit balance for the key' do
      BetterTogether::Billing::BenefitCredit.grant!(beneficiary: holder, benefit_key: 'event_registration', quantity: 1)

      result = described_class.call(holder:, entitlement_key: 'event_registration')

      expect(result).to be_entitled
      expect(result.resolution).to eq('credit')
      expect(result.credit_balance).to eq(1)
    end

    it 'is not entitled when the holder has no BenefitCredit balance for the key' do
      result = described_class.call(holder:, entitlement_key: 'event_registration')

      expect(result).not_to be_entitled
      expect(result.credit_balance).to eq(0)
    end
  end

  describe 'an unregistered entitlement_key' do
    it 'raises KeyError' do
      expect do
        described_class.call(holder:, entitlement_key: 'not_a_real_entitlement')
      end.to raise_error(KeyError)
    end
  end
end
