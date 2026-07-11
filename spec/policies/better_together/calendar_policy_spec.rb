# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CalendarPolicy, type: :policy do
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user) { create(:better_together_user, person: creator_person) }
  let(:normal_user) { create(:better_together_user) }
  # privacy: 'public' — the calendar below is created with privacy: 'public',
  # which would exceed this community's own (otherwise default-private)
  # privacy ceiling (see PrivacyCeilingValidatable).
  let(:host_community) { create(:better_together_community, privacy: 'public') }
  let(:calendar) { create(:better_together_calendar, creator: creator_person, community: host_community, privacy: 'public') }

  describe '#index?' do
    it 'allows authenticated user' do
      expect(described_class.new(normal_user, BetterTogether::Calendar).index?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::Calendar).index?).to be false
    end
  end

  describe '#show?' do
    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'when the creator views their calendar' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'allows show' do
        expect(described_class.new(creator_user, calendar).show?).to be true
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'when a platform manager views the calendar' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'allows show' do
        expect(described_class.new(steward_user, calendar).show?).to be true
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    it 'denies guest' do
      expect(described_class.new(nil, calendar).show?).to be false
    end
  end

  describe '#create?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    it 'allows platform steward (calendar manager)' do
      expect(described_class.new(steward_user, BetterTogether::Calendar).create?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::Calendar).create?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::Calendar).create?).to be false
    end
  end

  describe '#update?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'when the creator updates their calendar' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'allows update' do
        expect(described_class.new(creator_user, calendar).update?).to be true
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'when platform manager updates the calendar' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'allows update' do
        expect(described_class.new(steward_user, calendar).update?).to be true
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'when another user tries to update' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'denies update' do
        expect(described_class.new(normal_user, calendar).update?).to be false
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
