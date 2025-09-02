# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ChecklistPolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user) { create(:better_together_user, person: creator_person) }
  let(:normal_user) { create(:better_together_user) }

  let(:checklist) { create(:better_together_checklist, creator: creator_person) }

  describe '#create?' do
    subject { described_class.new(user, BetterTogether::Checklist).create? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'manager' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { manager_user }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'normal user' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it { is_expected.to be false }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe '#update?' do
    subject { described_class.new(user, checklist).update? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'manager' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { manager_user }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'creator' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { creator_user }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'normal user' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it { is_expected.to be false }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe '#destroy?' do
    subject { described_class.new(user, checklist).destroy? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'manager' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { manager_user }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'creator' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { creator_user }

      it { is_expected.to be false }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
