# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EntitlementHolder do
  describe '.included_in_models' do
    it 'includes Community and Person, the two current opt-in models' do
      expect(described_class.included_in_models).to include(BetterTogether::Community, BetterTogether::Person)
    end
  end

  describe '#billing_entitlements' do
    it 'is available on an including model and starts empty' do
      community = create(:better_together_community)

      expect(community.billing_entitlements).to eq([])
    end
  end

  describe '#entitled_to?' do
    it 'delegates to Billing::EntitlementResolver and reflects a current grant' do
      community = create(:better_together_community)
      BetterTogether::Billing::Entitlement.grant!(holder: community, entitlement_key: 'hosted_access')

      expect(community.entitled_to?('hosted_access')).to be(true)
    end

    it 'returns false when the holder has no matching grant' do
      community = create(:better_together_community)

      expect(community.entitled_to?('hosted_access')).to be(false)
    end
  end
end
