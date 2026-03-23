# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::BlockPolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }
  let(:block) { create(:content_markdown) }

  describe '#index?' do
    subject { described_class.new(user, block).index? }

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
    subject { described_class.new(user, block).show? }

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
    subject { described_class.new(user, block).create? }

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
    subject { described_class.new(user, block).new? }

    it 'delegates to create?' do
      policy = described_class.new(manager_user, block)
      expect(policy.new?).to eq(policy.create?)
    end
  end

  describe '#update?' do
    subject { described_class.new(user, block).update? }

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
    subject { described_class.new(user, block).edit? }

    it 'delegates to update?' do
      policy = described_class.new(manager_user, block)
      expect(policy.edit?).to eq(policy.update?)
    end
  end

  describe '#destroy?' do
    subject { described_class.new(user, block).destroy? }

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

  describe '#preview_markdown?' do
    subject { described_class.new(user, block).preview_markdown? }

    context 'when user is signed in' do
      let(:user) { normal_user }

      it { is_expected.to be true }
    end

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'when user is not signed in' do
      let(:user) { nil }

      it { is_expected.to be false }
    end

    it 'allows any authenticated user to preview markdown' do
      user = create(:better_together_user)
      policy = described_class.new(user, block)
      expect(policy.preview_markdown?).to be true
    end
  end

  describe 'Scope' do
    subject(:scope) { described_class::Scope.new(user, BetterTogether::Content::Block).resolve }

    let!(:markdown_block) { create(:content_markdown) }
    let!(:html_block) { create(:better_together_content_html) }
    let!(:page) { create(:better_together_page) }

    before do
      create(:page_content_block, page: page, block: markdown_block)
      create(:page_content_block, page: page, block: html_block)
    end

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it 'returns all blocks ordered by created_at DESC' do
        expect(scope).to include(markdown_block, html_block)
        expect(scope.first.created_at).to be >= scope.last.created_at
      end

      it 'includes associated pages' do
        expect(scope.first.association(:pages)).to be_loaded
      end
    end

    context 'when user is a normal user' do
      let(:user) { normal_user }

      it 'returns all blocks' do
        expect(scope).to include(markdown_block, html_block)
      end
    end
  end
end
