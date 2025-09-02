# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PagePolicy, type: :policy do # rubocop:todo RSpec/MultipleMemoizedHelpers
  let!(:public_published)   { create(:better_together_page, published_at: 1.day.ago, privacy: 'public') }
  let!(:public_unpublished) { create(:better_together_page, published_at: nil, privacy: 'public') }
  let!(:private_published)  { create(:better_together_page, published_at: 1.day.ago, privacy: 'private') }
  let!(:private_unpublished) { create(:better_together_page, published_at: nil, privacy: 'private') }

  let(:author_person) { create(:better_together_person) }
  let(:author_user)   { create(:better_together_user, person: author_person) }
  let(:manager_user)  { create(:better_together_user, :platform_manager) }
  let(:normal_user)   { create(:better_together_user) }

  before do
    # Grant authorship for the private/unpublished page
    private_unpublished.authorships.create!(author: author_person)
  end

  describe '#show?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject { described_class.new(user, page).show? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for published public pages' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:page) { public_published }

      # rubocop:todo RSpec/MultipleMemoizedHelpers
      # rubocop:todo RSpec/NestedGroups
      context 'anyone' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        let(:user) { nil }

        it { is_expected.to be true }
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for private or unpublished pages' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      # rubocop:todo RSpec/MultipleMemoizedHelpers
      # rubocop:todo RSpec/NestedGroups
      context 'manager' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        let(:user) { manager_user }
        let(:page) { private_unpublished }

        it { is_expected.to be true }
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers

      # rubocop:todo RSpec/MultipleMemoizedHelpers
      # rubocop:todo RSpec/NestedGroups
      context 'author' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        let(:user) { author_user }
        let(:page) { private_unpublished }

        it { is_expected.to be true }
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers

      # rubocop:todo RSpec/MultipleMemoizedHelpers
      # rubocop:todo RSpec/NestedGroups
      context 'normal user' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        let(:user) { normal_user }
        let(:page) { private_unpublished }

        it { is_expected.to be false }
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe '#update?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject { described_class.new(user, page).update? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'manager' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { manager_user }
      let(:page) { public_unpublished }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'author' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { author_user }
      let(:page) { private_unpublished }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'normal user' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }
      let(:page) { public_published }

      it { is_expected.to be false }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe 'Scope' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject { described_class::Scope.new(user, BetterTogether::Page).resolve }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'manager' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { manager_user }

      it 'includes all pages' do
        expect(subject).to match_array BetterTogether::Page.all # rubocop:todo RSpec/NamedSubject
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'author' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { author_user }

      it 'includes authored and published public pages' do # rubocop:todo RSpec/MultipleExpectations
        expect(subject).to include(public_published, private_unpublished) # rubocop:todo RSpec/NamedSubject
        expect(subject).not_to include(public_unpublished, private_published) # rubocop:todo RSpec/NamedSubject
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'normal user' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it 'includes published public pages and nothing else is guaranteed' do # rubocop:todo RSpec/MultipleExpectations
        expect(subject).to include(public_published) # rubocop:todo RSpec/NamedSubject
        # rubocop:todo RSpec/NamedSubject
        expect(subject).not_to include(public_unpublished, private_published, private_unpublished)
        # rubocop:enable RSpec/NamedSubject
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'guest' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { nil }

      it 'includes published public pages and nothing else is guaranteed' do # rubocop:todo RSpec/MultipleExpectations
        expect(subject).to include(public_published) # rubocop:todo RSpec/NamedSubject
        # rubocop:todo RSpec/NamedSubject
        expect(subject).not_to include(public_unpublished, private_published, private_unpublished)
        # rubocop:enable RSpec/NamedSubject
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
