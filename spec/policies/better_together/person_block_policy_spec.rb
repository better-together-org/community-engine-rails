# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonBlockPolicy do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:agent) { user.person }
  let(:other) { create(:better_together_person) }

  describe '#index?' do
    it 'allows signed-in users' do
      expect(described_class.new(user, BetterTogether::PersonBlock).index?).to be true
    end
  end

  describe '#create?' do
    it 'permits when agent is blocker and blocked is not a platform manager' do
      record = BetterTogether::PersonBlock.new(blocker: agent, blocked: other)
      expect(described_class.new(user, record).create?).to be true
    end

    it 'denies when blocked is a platform manager' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      manager_user = create(:better_together_user, :confirmed)
      platform_manager_role = BetterTogether::Role.find_by(identifier: 'platform_manager')
      BetterTogether::PersonPlatformMembership.create!(
        joinable: host_platform,
        member: manager_user.person,
        role: platform_manager_role
      )

      record = BetterTogether::PersonBlock.new(blocker: agent, blocked: manager_user.person)
      expect(described_class.new(user, record).create?).to be false
    end

    it 'denies when reporter is not the blocker' do
      record = BetterTogether::PersonBlock.new(blocker: other, blocked: agent)
      expect(described_class.new(user, record).create?).to be false
    end
  end

  describe '#destroy?' do
    it 'permits when agent is blocker' do
      record = BetterTogether::PersonBlock.new(blocker: agent, blocked: other)
      expect(described_class.new(user, record).destroy?).to be true
    end

    it 'denies when agent is not blocker' do
      record = BetterTogether::PersonBlock.new(blocker: other, blocked: agent)
      expect(described_class.new(user, record).destroy?).to be false
    end
  end
end
