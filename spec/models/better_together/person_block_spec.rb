# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonBlock, type: :model do
  let(:blocker) { create(:better_together_person) }
  let(:blocked) { create(:better_together_person) }

  it 'allows a person to block another person' do
    block = described_class.create(blocker:, blocked:)
    expect(block).to be_persisted
    expect(blocker.blocked_people).to include(blocked)
  end

  it 'does not allow blocking platform managers' do
    platform = create(:platform)
    role = create(:better_together_role, identifier: 'platform_manager', resource_type: 'BetterTogether::Platform')
    BetterTogether::PersonPlatformMembership.create!(member: blocked, joinable: platform, role:)

    block = described_class.new(blocker:, blocked:)
    expect(block).not_to be_valid
    expect(block.errors[:blocked]).to include('cannot be a platform manager')
  end
end
