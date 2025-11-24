# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::MarkdownPolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }
  let(:markdown_block) { create(:content_markdown) }

  describe '#index?' do
    subject { described_class.new(user, markdown_block).index? }

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
    subject { described_class.new(user, markdown_block).show? }

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

  describe '#create?' do
    subject { described_class.new(user, markdown_block).create? }

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

  describe '#new?' do
    subject { described_class.new(user, markdown_block).new? }

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'when user is a normal user' do
      let(:user) { normal_user }

      it { is_expected.to be false }
    end
  end

  describe '#update?' do
    subject { described_class.new(user, markdown_block).update? }

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

  describe '#edit?' do
    subject { described_class.new(user, markdown_block).edit? }

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'when user is a normal user' do
      let(:user) { normal_user }

      it { is_expected.to be false }
    end
  end

  describe '#destroy?' do
    subject { described_class.new(user, markdown_block).destroy? }

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

  describe 'Scope' do
    let!(:markdown_block1) { create(:content_markdown) }
    let!(:markdown_block2) { create(:content_markdown) }

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it 'returns all markdown blocks' do
        scope = described_class::Scope.new(user, BetterTogether::Content::Markdown.all).resolve
        expect(scope).to include(markdown_block1, markdown_block2)
      end
    end

    context 'when user is a normal user' do
      let(:user) { normal_user }

      it 'returns all markdown blocks (filtering happens in policy methods)' do
        scope = described_class::Scope.new(user, BetterTogether::Content::Markdown.all).resolve
        expect(scope).to include(markdown_block1, markdown_block2)
      end
    end
  end
end
