# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OwnershipResolver do
  describe '.supported_owner_types' do
    it 'is the union of Billable and SponsorshipRecipient includers' do
      expected = (
        BetterTogether::Billing::Billable.included_in_models +
        BetterTogether::Billing::SponsorshipRecipient.included_in_models
      ).map(&:name).uniq

      expect(described_class.supported_owner_types).to match_array(expected)
      expect(described_class.supported_owner_types).to include('BetterTogether::Community', 'BetterTogether::Person')
    end
  end

  describe '.supported_owner_type_name' do
    it 'resolves the full namespaced name unchanged' do
      expect(described_class.supported_owner_type_name('BetterTogether::Community')).to eq('BetterTogether::Community')
    end

    it 'resolves the demodulized capitalized short name' do
      expect(described_class.supported_owner_type_name('Person')).to eq('BetterTogether::Person')
    end

    it 'resolves the lowercase short name' do
      expect(described_class.supported_owner_type_name('community')).to eq('BetterTogether::Community')
    end

    it 'returns nil for an unsupported type name' do
      expect(described_class.supported_owner_type_name('BetterTogether::Billing::Plan')).to be_nil
    end
  end

  describe '.resolve_record' do
    it 'resolves a record by short type name and id' do
      community = create(:better_together_community)

      expect(described_class.resolve_record('community', community.id)).to eq(community)
    end

    it 'returns nil for an unsupported type' do
      plan = create(:better_together_billing_plan)

      expect(described_class.resolve_record('BetterTogether::Billing::Plan', plan.id)).to be_nil
    end
  end

  describe '.supported_owner_type?' do
    it 'returns true for a Billable/SponsorshipRecipient record' do
      expect(described_class.supported_owner_type?(create(:better_together_person))).to be(true)
    end

    it 'returns false for a record whose class is not an includer' do
      expect(described_class.supported_owner_type?(create(:better_together_billing_plan))).to be(false)
    end
  end

  describe '.build_metadata' do
    it 'includes explicit billable_owner/beneficiary keys only for supported owner types' do
      billing_plan = create(:better_together_billing_plan)
      community = create(:better_together_community)

      metadata = described_class.build_metadata(billing_plan:, billable_owner: community, beneficiary: community)

      expect(metadata).to include(
        bt_billable_owner_type: 'BetterTogether::Community',
        bt_billable_owner_id: community.id,
        bt_beneficiary_type: 'BetterTogether::Community',
        bt_beneficiary_id: community.id
      )
    end
  end
end
