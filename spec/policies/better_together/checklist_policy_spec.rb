# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ChecklistPolicy, type: :policy do
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user) { create(:better_together_user, person: creator_person) }
  let(:normal_user) { create(:better_together_user) }
  let(:community_checklist) { create(:better_together_checklist, creator: creator_person, privacy: 'community') }
  let(:public_checklist) { create(:better_together_checklist, creator: creator_person, privacy: 'public') }

  let(:checklist) { create(:better_together_checklist, creator: creator_person) }

  describe '#create?' do
    subject { described_class.new(user, BetterTogether::Checklist).create? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'platform steward' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { steward_user }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'normal user' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it { is_expected.to be false }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe '#update?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject { described_class.new(user, checklist).update? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'platform steward' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { steward_user }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'creator' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { creator_user }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'normal user' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it { is_expected.to be false }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe '#show?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject { described_class.new(user, record).show? }

    context 'for a community checklist and signed-in non-member' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }
      let(:record) { community_checklist }

      it { is_expected.to be false }
    end

    context 'for a community checklist and creator' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { creator_user }
      let(:record) { community_checklist }

      it { is_expected.to be true }
    end

    context 'for a community checklist and guest' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { nil }
      let(:record) { community_checklist }

      it { is_expected.to be false }
    end
  end

  describe '#destroy?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject { described_class.new(user, checklist).destroy? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'platform steward' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { steward_user }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'creator' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { creator_user }

      it { is_expected.to be false }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe 'Scope' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject(:resolved) { described_class::Scope.new(user, BetterTogether::Checklist).resolve }

    context 'signed-in non-member' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it 'excludes unsupported community checklists' do
        public_checklist
        community_checklist

        expect(resolved).to include(public_checklist)
        expect(resolved).not_to include(community_checklist)
      end
    end

    context 'creator' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { creator_user }

      it 'includes the creator-owned community checklist' do
        public_checklist
        community_checklist

        expect(resolved).to include(public_checklist, community_checklist)
      end
    end

    context 'guest' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { nil }

      it 'excludes community checklists' do
        public_checklist
        community_checklist

        expect(resolved).to include(public_checklist)
        expect(resolved).not_to include(community_checklist)
      end
    end
  end
end
