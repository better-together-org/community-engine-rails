# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonBlock do
  let(:blocker) { create(:better_together_person) }
  let(:blocked) { create(:better_together_person) }

  it 'allows a person to block another person' do # rubocop:todo RSpec/MultipleExpectations
    block = described_class.create(blocker:, blocked:)
    expect(block).to be_persisted
    expect(blocker.blocked_people).to include(blocked)
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'does not allow blocking platform managers' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    platform = create(:platform)
    role = BetterTogether::Role.find_by(identifier: 'platform_manager', resource_type: 'BetterTogether::Platform') ||
           create(:better_together_role, identifier: 'platform_manager', resource_type: 'BetterTogether::Platform',
                                         name: 'Platform Manager')
    BetterTogether::PersonPlatformMembership.create!(member: blocked, joinable: platform, role:)

    block = described_class.new(blocker:, blocked:)
    expect(block).not_to be_valid
    expect(block.errors[:blocked]).to include('cannot be a platform manager')
  end
end
