# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BreakGlassGrantPolicy do
  let(:grant) { create(:better_together_break_glass_grant) }
  let(:platform) { grant.platform }

  def user_with_role(identifier)
    user = create(:better_together_user, :confirmed)
    role = BetterTogether::Role.find_default(identifier, platform:)
    BetterTogether::PersonPlatformMembership.create!(joinable: platform, member: user.person, role:, status: 'active')
    user
  end

  it 'lets a sealed holder see and request' do
    policy = described_class.new(user_with_role('platform_disclosure_officer'), grant)
    expect([policy.show?, policy.create?, policy.index?]).to eq([true, true, true])
  end

  it 'gives a platform steward nothing' do
    policy = described_class.new(user_with_role('platform_steward'), grant)
    expect([policy.show?, policy.create?, policy.index?, policy.revoke?]).to eq([false, false, false, false])
  end

  it 'lets the grantee see their own grant' do
    policy = described_class.new(grant.grantee.user || create(:better_together_user, person: grant.grantee), grant)
    expect(policy.show?).to be true
  end

  it 'never allows update or destroy' do
    policy = described_class.new(user_with_role('platform_disclosure_officer'), grant)
    expect([policy.update?, policy.destroy?]).to eq([false, false])
  end

  it 'denies anonymous visitors' do
    expect(described_class.new(nil, grant).show?).to be false
  end
end
