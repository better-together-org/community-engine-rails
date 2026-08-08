# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Entitlement do
  let(:holder) { create(:better_together_community) }

  describe 'validations' do
    subject(:entitlement) { build(:better_together_billing_entitlement, holder:) }

    it 'is valid with a known entitlement_key, a supported holder type, and a granted_at' do
      expect(entitlement).to be_valid
    end

    it 'rejects an unknown entitlement_key' do
      entitlement.entitlement_key = 'not_a_real_entitlement'

      expect(entitlement).not_to be_valid
      expect(entitlement.errors[:entitlement_key]).to be_present
    end

    it 'rejects a holder type that does not include Billing::EntitlementHolder' do
      entitlement.holder = build(:better_together_billing_plan)

      expect(entitlement).not_to be_valid
      expect(entitlement.errors[:holder_type]).to be_present
    end

    it 'rejects an unknown status' do
      entitlement.status = 'not_a_real_status'

      expect(entitlement).not_to be_valid
      expect(entitlement.errors[:status]).to be_present
    end

    it 'requires granted_at' do
      entitlement.granted_at = nil

      expect(entitlement).not_to be_valid
      expect(entitlement.errors[:granted_at]).to be_present
    end
  end

  describe '.grant!' do
    it 'creates an active entitlement row' do
      entitlement = described_class.grant!(holder:, entitlement_key: 'hosted_access')

      expect(entitlement).to be_persisted
      expect(entitlement.status).to eq('active')
      expect(entitlement.granted_at).to be_present
    end

    it 'upserts the same row for the same holder+key+source rather than creating a duplicate' do
      first = described_class.grant!(holder:, entitlement_key: 'hosted_access')
      second = described_class.grant!(holder:, entitlement_key: 'hosted_access')

      expect(second.id).to eq(first.id)
      expect(described_class.for_holder_and_key(holder, 'hosted_access').count).to eq(1)
    end

    it 'preserves the original granted_at across repeated grants' do
      first = described_class.grant!(holder:, entitlement_key: 'hosted_access')
      original_granted_at = first.granted_at

      travel_to(1.day.from_now) { described_class.grant!(holder:, entitlement_key: 'hosted_access') }

      expect(first.reload.granted_at).to be_within(1.second).of(original_granted_at)
    end

    it 'reactivates a previously-revoked entitlement rather than creating a second row' do
      described_class.grant!(holder:, entitlement_key: 'hosted_access')
      described_class.revoke!(holder:, entitlement_key: 'hosted_access')

      regranted = described_class.grant!(holder:, entitlement_key: 'hosted_access')

      expect(regranted.status).to eq('active')
      expect(regranted.revoked_at).to be_nil
      expect(described_class.for_holder_and_key(holder, 'hosted_access').count).to eq(1)
    end

    it 'distinguishes rows by source, allowing the same holder+key to be granted from two different sources' do
      other_holder_source = create(:better_together_community)

      first = described_class.grant!(holder:, entitlement_key: 'hosted_access', source: nil)
      second = described_class.grant!(holder:, entitlement_key: 'hosted_access', source: other_holder_source)

      expect(first.id).not_to eq(second.id)
      expect(described_class.for_holder_and_key(holder, 'hosted_access').count).to eq(2)
    end
  end

  describe '.revoke!' do
    it 'flips a matching entitlement to revoked and stamps revoked_at' do
      described_class.grant!(holder:, entitlement_key: 'hosted_access')

      revoked = described_class.revoke!(holder:, entitlement_key: 'hosted_access')

      expect(revoked.status).to eq('revoked')
      expect(revoked.revoked_at).to be_present
    end

    it 'is a no-op when no matching entitlement exists' do
      expect(described_class.revoke!(holder:, entitlement_key: 'hosted_access')).to be_nil
    end

    it 'is a no-op when the entitlement is already revoked' do
      described_class.grant!(holder:, entitlement_key: 'hosted_access')
      described_class.revoke!(holder:, entitlement_key: 'hosted_access')

      expect(described_class.revoke!(holder:, entitlement_key: 'hosted_access')).to be_nil
    end
  end

  describe '.current' do
    it 'includes an active, non-expired entitlement' do
      entitlement = described_class.grant!(holder:, entitlement_key: 'hosted_access')

      expect(described_class.current).to include(entitlement)
    end

    it 'excludes a revoked entitlement' do
      entitlement = described_class.grant!(holder:, entitlement_key: 'hosted_access')
      described_class.revoke!(holder:, entitlement_key: 'hosted_access')

      expect(described_class.current).not_to include(entitlement)
    end

    it 'excludes an entitlement past its expires_at' do
      entitlement = described_class.grant!(holder:, entitlement_key: 'hosted_access', expires_at: 1.day.ago)

      expect(described_class.current).not_to include(entitlement)
    end

    it 'includes an entitlement with a future expires_at' do
      entitlement = described_class.grant!(holder:, entitlement_key: 'hosted_access', expires_at: 1.day.from_now)

      expect(described_class.current).to include(entitlement)
    end
  end
end
