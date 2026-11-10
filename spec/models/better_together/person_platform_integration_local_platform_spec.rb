# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonPlatformIntegration, '#local_platform' do
  let(:platform_a) { create(:better_together_platform) }
  let(:platform_b) { create(:better_together_platform) }

  def link(local_platform, uid: 'same-uid')
    create(:person_platform_integration, provider: 'github', uid:, local_platform:)
  end

  it 'allows the same provider account on different platforms' do
    link(platform_a)

    expect(link(platform_b)).to be_persisted
  end

  it 'rejects the same provider account twice on one platform' do
    link(platform_a)
    duplicate = build(:person_platform_integration, provider: 'github', uid: 'same-uid', local_platform: platform_a)

    expect(duplicate).not_to be_valid
  end

  it 'finds an identity only on the platform it was linked on', :aggregate_failures do
    integration = link(platform_a)

    expect(described_class.find_by(provider: 'github', uid: 'same-uid', local_platform: platform_a)).to eq(integration)
    expect(described_class.find_by(provider: 'github', uid: 'same-uid', local_platform: platform_b)).to be_nil
  end
end
