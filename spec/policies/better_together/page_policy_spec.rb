require 'rails_helper'

RSpec.describe BetterTogether::PagePolicy, type: :policy do
  let!(:public_published)   { create(:better_together_page, published_at: 1.day.ago, privacy: 'public') }
  let!(:public_unpublished) { create(:better_together_page, published_at: nil,          privacy: 'public') }
  let!(:private_published)  { create(:better_together_page, published_at: 1.day.ago, privacy: 'private') }
  let!(:private_unpublished){ create(:better_together_page, published_at: nil,          privacy: 'private') }

  let(:author_person) { create(:better_together_person) }
  let(:author_user)   { create(:better_together_user, person: author_person) }
  let(:manager_user)  { create(:better_together_user, :platform_manager) }
  let(:normal_user)   { create(:better_together_user) }

  before do
    # Grant authorship for the private/unpublished page
    private_unpublished.authorships.create!(author: author_person)
  end

  describe '#show?' do
    subject { described_class.new(user, page).show? }

    context 'for published public pages' do
      let(:page) { public_published }
      context 'anyone' do
        let(:user) { nil }
        it { is_expected.to eq true }
      end
    end

    context 'for private or unpublished pages' do
      context 'manager' do
        let(:user) { manager_user }
        let(:page) { private_unpublished }
        it { is_expected.to eq true }
      end

      context 'author' do
        let(:user) { author_user }
        let(:page) { private_unpublished }
        it { is_expected.to eq true }
      end

      context 'normal user' do
        let(:user) { normal_user }
        let(:page) { private_unpublished }
        it { is_expected.to eq false }
      end
    end
  end

  describe '#update?' do
    subject { described_class.new(user, page).update? }

    context 'manager' do
      let(:user) { manager_user }
      let(:page) { public_unpublished }
      it { is_expected.to eq true }
    end

    context 'author' do
      let(:user) { author_user }
      let(:page) { private_unpublished }
      it { is_expected.to eq true }
    end

    context 'normal user' do
      let(:user) { normal_user }
      let(:page) { public_published }
      it { is_expected.to eq false }
    end
  end

  describe 'Scope' do
    subject { described_class::Scope.new(user, BetterTogether::Page).resolve }

    context 'manager' do
      let(:user) { manager_user }
      it 'includes all pages' do
        expect(subject).to match_array BetterTogether::Page.all
      end
    end

    context 'author' do
      let(:user) { author_user }
      it 'includes authored and published public pages' do
        expect(subject).to include(public_published, private_unpublished)
        expect(subject).not_to include(public_unpublished, private_published)
      end
    end

    context 'normal user' do
      let(:user) { normal_user }
      it 'includes published public pages and nothing else is guaranteed' do
        expect(subject).to include(public_published)
        expect(subject).not_to include(public_unpublished, private_published, private_unpublished)
      end
    end

    context 'guest' do
      let(:user) { nil }
      it 'includes published public pages and nothing else is guaranteed' do
        expect(subject).to include(public_published)
        expect(subject).not_to include(public_unpublished, private_published, private_unpublished)
      end
    end
  end
end
