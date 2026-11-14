# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformIdentityProviderPolicy do
  let!(:platform) { configure_host_platform }
  let(:record) { platform.platform_identity_providers.build }

  it 'denies a user with no platform permissions', :aggregate_failures do
    user = create(:better_together_user, :confirmed)
    policy = described_class.new(user, record)

    expect([policy.index?, policy.create?, policy.update?, policy.destroy?]).to all(be(false))
  end

  it 'denies a missing agent' do
    expect(described_class.new(nil, record).index?).to be(false)
  end

  it 'allows a platform manager', :aggregate_failures do
    user = find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager)
    policy = described_class.new(user, record)

    expect([policy.index?, policy.create?, policy.update?, policy.destroy?]).to all(be(true))
  end
end
