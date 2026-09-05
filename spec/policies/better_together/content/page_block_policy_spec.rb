# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::PageBlockPolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user)  { create(:better_together_user) }
  let(:page_block)   { create(:page_content_block) }

  describe '#index?' do
    subject { described_class.new(user, page_block).index? }

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'when user is a normal user' do
      let(:user) { normal_user }

      it { is_expected.to be false }
    end

    context 'when user is not signed in' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#show?' do
    subject { described_class.new(user, page_block).show? }

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'when user is not signed in' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#create?' do
    subject { described_class.new(user, page_block).create? }

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'when user is not signed in' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#update?' do
    subject { described_class.new(user, page_block).update? }

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'when user is not signed in' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#destroy?' do
    subject { described_class.new(user, page_block).destroy? }

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'when user is not signed in' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe 'Scope#resolve' do
    context 'when user is a platform manager' do
      it 'returns all page blocks' do
        page_block
        scope = described_class::Scope.new(manager_user, BetterTogether::Content::PageBlock)
        expect(scope.resolve).to include(page_block)
      end
    end

    context 'when user is not signed in' do
      it 'returns none' do
        scope = described_class::Scope.new(nil, BetterTogether::Content::PageBlock)
        expect(scope.resolve).to eq(BetterTogether::Content::PageBlock.none)
      end
    end
  end
end
