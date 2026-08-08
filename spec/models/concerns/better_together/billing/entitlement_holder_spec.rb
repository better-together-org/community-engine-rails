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
end
