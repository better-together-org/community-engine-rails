# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::RolePolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }

  let(:role) { create(:better_together_role) }
  let(:protected_role) { create(:better_together_role, protected: true) }

  describe '#index?' do
    subject { described_class.new(user, BetterTogether::Role).index? }

    context 'authenticated user' do
      let(:user) { normal_user }

      it { is_expected.to be true }
    end

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#show?' do
    subject { described_class.new(user, role).show? }

    context 'authenticated user' do
      let(:user) { normal_user }

      it { is_expected.to be true }
    end

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#create?' do
    subject { described_class.new(user, BetterTogether::Role).create? }

    context 'any user' do
      let(:user) { manager_user }

      it { is_expected.to be false }
    end
  end

  describe '#update?' do
    subject { described_class.new(user, role).update? }

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

  describe '#destroy?' do
    context 'unprotected role' do
      subject { described_class.new(user, role).destroy? }

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

    context 'protected role' do
      subject { described_class.new(user, protected_role).destroy? }

      context 'platform manager' do
        let(:user) { manager_user }

        it { is_expected.to be false }
      end
    end
  end
end
