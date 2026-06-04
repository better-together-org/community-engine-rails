# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/NamedSubject

RSpec.describe BetterTogether::PagePolicy, type: :policy do # rubocop:todo RSpec/MultipleMemoizedHelpers
  let(:scoped_community) { create(:better_together_community, privacy: 'public') }
  let(:scoped_platform) { create(:better_together_platform, community: scoped_community) }
  let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
  let!(:public_published) { create(:better_together_page, published_at: 1.day.ago, privacy: 'public') }
  let!(:community_published) do
    create(
      :better_together_page,
      published_at: 1.day.ago,
      privacy: 'community',
      platform: scoped_platform,
      community: scoped_community
    )
  end
  let!(:public_unpublished) { create(:better_together_page, published_at: nil, privacy: 'public') }
  let!(:private_published) { create(:better_together_page, published_at: 1.day.ago, privacy: 'private') }
  let!(:private_unpublished) { create(:better_together_page, published_at: nil, privacy: 'private') }

  let(:author_person) { create(:better_together_person) }
  let(:author_user) { create(:better_together_user, person: author_person) }
  let(:editor_person) { create(:better_together_person) }
  let(:editor_user) { create(:better_together_user, person: editor_person) }
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:normal_user) { create(:better_together_user) }
  let(:community_member_user) { create(:better_together_user) }
  let(:robot_author) { create(:robot, platform: private_unpublished.platform) }

  before do
    # Grant authorship for the private/unpublished page
    private_unpublished.authorships.create!(author: author_person)
    private_unpublished.add_governed_contributor(editor_person, role: 'editor')
    BetterTogether::PersonCommunityMembership.find_or_create_by!(
      joinable: scoped_community,
      member: community_member_user.person,
      role: community_member_role
    )
  end

  describe '#show?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject { described_class.new(user, page).show? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for published public pages' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:page) { public_published }

      # rubocop:todo RSpec/MultipleMemoizedHelpers
      # rubocop:todo RSpec/NestedGroups
      context 'anyone' do # rubocop:todo RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        let(:user) { nil }

        it { is_expected.to be true }
      end

      context 'authorized robot' do
        let(:user) do
          create(
            :robot,
            platform: page.platform,
            settings: {
              bot_access_enabled: true,
              bot_access_scopes: %w[read_public_content],
              bot_access_token_digest: BetterTogether::Robot.bot_access_token_digest('token')
            }
          )
        end

        it { is_expected.to be true }
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    context 'for published community pages' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:page) { community_published }

      context 'community member' do # rubocop:todo RSpec/MultipleMemoizedHelpers
        let(:user) { community_member_user }

        it { is_expected.to be true }
      end

      context 'signed-in non-member' do # rubocop:todo RSpec/MultipleMemoizedHelpers
        let(:user) { normal_user }

        it { is_expected.to be false }
      end

      context 'guest' do # rubocop:todo RSpec/MultipleMemoizedHelpers
        let(:user) { nil }

        it { is_expected.to be false }
      end
    end

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'for private or unpublished pages' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      # rubocop:todo RSpec/MultipleMemoizedHelpers
      # rubocop:todo RSpec/NestedGroups
      context 'platform steward' do # rubocop:todo RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        let(:user) { steward_user }
        let(:page) { private_unpublished }

        it { is_expected.to be true }
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers

      # rubocop:todo RSpec/MultipleMemoizedHelpers
      # rubocop:todo RSpec/NestedGroups
      context 'author' do # rubocop:todo RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        let(:user) { author_user }
        let(:page) { private_unpublished }

        it { is_expected.to be true }
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers

      context 'editor' do # rubocop:todo RSpec/MultipleMemoizedHelpers
        let(:user) { editor_user }
        let(:page) { private_unpublished }

        it { is_expected.to be true }
      end

      # rubocop:todo RSpec/MultipleMemoizedHelpers
      # rubocop:todo RSpec/NestedGroups
      context 'normal user' do # rubocop:todo RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        let(:user) { normal_user }
        let(:page) { private_unpublished }

        it { is_expected.to be false }
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers
    end

    context 'for published private pages and an authorized robot' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:page) { private_published }
      let(:user) do
        create(
          :robot,
          platform: page.platform,
          settings: {
            bot_access_enabled: true,
            bot_access_scopes: %w[read_private_content],
            bot_access_token_digest: BetterTogether::Robot.bot_access_token_digest('token')
          }
        )
      end

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe '#update?' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject { described_class.new(user, page).update? }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'platform steward' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { steward_user }
      let(:page) { public_unpublished }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'author' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { author_user }
      let(:page) { private_unpublished }

      it { is_expected.to be true }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    context 'editor' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { editor_user }
      let(:page) { private_unpublished }

      it { is_expected.to be true }
    end

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'normal user' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }
      let(:page) { public_published }

      it { is_expected.to be false }
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe 'Scope' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject(:resolved_scope) { described_class::Scope.new(user, BetterTogether::Page).resolve }

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'platform steward' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { steward_user }

      it 'includes all pages' do
        expect(resolved_scope).to match_array BetterTogether::Page.all
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'author' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { author_user }

      it 'includes authored and published public pages' do
        expect(resolved_scope).to include(public_published, private_unpublished)
        expect(resolved_scope).not_to include(community_published)
        expect(resolved_scope).not_to include(public_unpublished, private_published)
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    context 'editor' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { editor_user }

      it 'includes contributed and published public pages' do
        expect(resolved_scope).to include(public_published, private_unpublished)
        expect(resolved_scope).not_to include(public_unpublished, private_published)
      end
    end

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'normal user' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it 'includes published public pages and nothing else is guaranteed' do
        expect(resolved_scope).to include(public_published)
        expect(resolved_scope).not_to include(community_published, public_unpublished, private_published, private_unpublished)
      end

      it 'does not treat a robot-authored private page as authored by an unrelated human user' do
        private_unpublished.authorships.where(author: author_person).delete_all
        private_unpublished.authorships.create!(author: robot_author)
        expect(resolved_scope).not_to include(private_unpublished)
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'community member' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { community_member_user }

      it 'includes published pages scoped to the member community' do
        expect(resolved_scope).to include(public_published, community_published)
        expect(resolved_scope).not_to include(public_unpublished, private_published, private_unpublished)
      end
    end

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'guest' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { nil }

      it 'includes published public pages and nothing else is guaranteed' do
        expect(resolved_scope).to include(public_published)
        expect(resolved_scope).not_to include(community_published, public_unpublished, private_published, private_unpublished)
      end
    end

    context 'authorized robot' do
      let(:user) do
        create(
          :robot,
          platform: scoped_platform,
          settings: {
            bot_access_enabled: true,
            bot_access_scopes: %w[read_private_content],
            bot_access_token_digest: BetterTogether::Robot.bot_access_token_digest('token')
          }
        )
      end

      it 'includes published content across public, community, and private visibility levels' do
        expect(resolved_scope).to include(public_published, community_published, private_published)
        expect(resolved_scope).not_to include(public_unpublished, private_unpublished)
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/NamedSubject
