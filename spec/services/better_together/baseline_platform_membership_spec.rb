# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BaselinePlatformMembership do
  let(:platform) { configure_host_platform }
  let(:person) { create(:better_together_person) }
  let(:role) { BetterTogether::Role.find_default('platform_member', platform:) }

  def memberships
    platform.person_platform_memberships.where(member: person, role:)
  end

  before { platform }

  it 'gives the person the platform_member role on the platform' do
    membership = described_class.call(person:, platform:)

    expect(membership).to be_persisted
    expect(membership).to have_attributes(member: person, joinable: platform, role:, status: 'active')
  end

  it 'uses the status the caller asks for' do
    expect(described_class.call(person:, platform:, status: 'pending')).to be_pending
  end

  it 'is idempotent' do
    described_class.call(person:, platform:)

    expect { described_class.call(person:, platform:) }.not_to change(memberships, :count)
  end

  it 'never sets an existing membership back to pending' do
    described_class.call(person:, platform:, status: 'active')

    expect(described_class.call(person:, platform:, status: 'pending')).to be_active
  end

  it 'stacks on top of an elevated role instead of replacing it' do
    steward = BetterTogether::Role.find_default('platform_steward', platform:)
    platform.person_platform_memberships.create!(member: person, role: steward, status: 'active')

    described_class.call(person:, platform:)

    expect(platform.person_platform_memberships.where(member: person).map { |m| m.role.identifier })
      .to contain_exactly('platform_steward', 'platform_member')
  end

  it 'does not notify the person' do
    allow(BetterTogether::MembershipCreatedNotifier).to receive(:with).and_call_original

    described_class.call(person:, platform:)

    expect(BetterTogether::MembershipCreatedNotifier).not_to have_received(:with)
  end

  it 'does nothing for a remote platform' do
    remote = create(:better_together_platform, :remote)

    expect(described_class.call(person:, platform: remote)).to be_nil
  end

  it 'does nothing without a person' do
    expect(described_class.call(person: nil, platform:)).to be_nil
  end
end
