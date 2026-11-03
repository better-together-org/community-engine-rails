# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Billable do
  it 'is on the models that can own billing records, so events and plans accept them as owners' do
    expect(described_class.model_names).to include('BetterTogether::Community', 'BetterTogether::Platform', 'BetterTogether::Person')
  end

  it 'binds a community to its platform and a platform to itself, for real (no stubbing)' do
    platform = create(:better_together_platform)
    community = create(:better_together_community, platform:)

    expect(community.billing_bound_platform_id).to eq(platform.id)
    expect(platform.billing_bound_platform_id).to eq(platform.id)
  end

  it 'refuses a Pay customer whose platform differs from the community that owns it' do
    platform = create(:better_together_platform)
    other = create(:better_together_platform)
    community = create(:better_together_community, platform:)

    customer = Pay::Customer.new(owner: community, platform: other, processor: 'fake_processor', processor_id: 'cus_x')

    expect(customer).not_to be_valid
    expect(customer.errors.details[:platform].pluck(:error)).to include(:platform_owner_mismatch)
  end
end
