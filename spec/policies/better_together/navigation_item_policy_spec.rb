# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::NavigationItemPolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }

  let(:navigation_item) { create(:better_together_navigation_item, protected: false) }
  let(:protected_item) { create(:better_together_navigation_item, protected: true) }

  describe '#index?' do
    subject { described_class.new(user, BetterTogether::NavigationItem).index? }

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be true }
    end

    context 'authenticated user' do
      let(:user) { normal_user }

      it { is_expected.to be true }
    end
  end

  describe '#show?' do
    subject { described_class.new(user, navigation_item).show? }

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be true }
    end

    context 'authenticated user' do
      let(:user) { normal_user }

      it { is_expected.to be true }
    end
  end

  describe '#create?' do
    subject { described_class.new(user, BetterTogether::NavigationItem).create? }

    context 'platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'normal user' do
      let(:user) { normal_user }

      it { is_expected.to be false }
    end

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#update?' do
    subject { described_class.new(user, navigation_item).update? }

    context 'platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'normal user' do
      let(:user) { normal_user }

      it { is_expected.to be false }
    end

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#destroy? unprotected item' do
    subject { described_class.new(user, navigation_item).destroy? }

    context 'platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'normal user' do
      let(:user) { normal_user }

      it { is_expected.to be false }
    end

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#destroy? protected item' do
    subject { described_class.new(user, protected_item).destroy? }

    context 'platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be false }
    end
  end
end
