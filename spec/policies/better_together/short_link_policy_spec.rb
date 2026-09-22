# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ShortLinkPolicy, type: :policy do
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user) { create(:better_together_user, person: creator_person) }
  let(:normal_user) { create(:better_together_user) }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:short_link) { create(:better_together_short_link, creator: creator_person, platform: host_platform) }

  describe '#index?' do
    it 'allows authenticated user' do
      expect(described_class.new(normal_user, BetterTogether::ShortLink).index?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::ShortLink).index?).to be false
    end
  end

  describe '#create?' do
    it 'allows authenticated user' do
      expect(described_class.new(normal_user, BetterTogether::ShortLink).create?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::ShortLink).create?).to be false
    end
  end

  describe '#show?' do
    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for the creator' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'allows show' do
        expect(described_class.new(creator_user, short_link).show?).to be true
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for a platform manager' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'allows show' do
        expect(described_class.new(steward_user, short_link).show?).to be true
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for another user' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'denies show' do
        expect(described_class.new(normal_user, short_link).show?).to be false
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe '#update?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for the creator' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'allows update' do
        expect(described_class.new(creator_user, short_link).update?).to be true
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for another user' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'denies update' do
        expect(described_class.new(normal_user, short_link).update?).to be false
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe '#destroy?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for a platform manager' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'allows destroy' do
        expect(described_class.new(steward_user, short_link).destroy?).to be true
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for another user (not creator)' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'denies destroy' do
        expect(described_class.new(normal_user, short_link).destroy?).to be false
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    it 'denies guest' do
      expect(described_class.new(nil, short_link).destroy?).to be false
    end
  end
end
