# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ChecklistItemPolicy, type: :policy do # rubocop:todo RSpec/MultipleMemoizedHelpers
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user) { create(:better_together_user, person: creator_person) }
  let(:normal_user) { create(:better_together_user) }

  let(:checklist) { create(:better_together_checklist, creator: creator_person) }
  let(:item) { create(:better_together_checklist_item, checklist: checklist) }

  describe '#create?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject { described_class.new(user, item).create? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'manager' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { manager_user }

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
    subject { described_class.new(user, item).update? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'manager' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { manager_user }

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

  describe '#destroy?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject { described_class.new(user, item).destroy? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'manager' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { manager_user }

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
end
