# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PostPolicy do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:creator_user) { create(:better_together_user, :confirmed) }

  let(:public_published_post) do
    create(
      :better_together_post,
      creator: creator_user.person,
      author: creator_user.person,
      privacy: 'public',
      published_at: 1.minute.ago
    )
  end

  let(:private_published_post) do
    create(
      :better_together_post,
      creator: creator_user.person,
      author: creator_user.person,
      privacy: 'private',
      published_at: 1.minute.ago
    )
  end

  let(:draft_post) do
    create(
      :better_together_post,
      creator: creator_user.person,
      author: creator_user.person,
      privacy: 'public',
      published_at: nil
    )
  end

  describe '#index?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, BetterTogether::Post).index?).to be true
    end

    it 'allows regular users' do
      expect(described_class.new(regular_user, BetterTogether::Post).index?).to be true
    end

    it 'allows unauthenticated users' do
      expect(described_class.new(nil, BetterTogether::Post)).to be_index
    end
  end

  describe '#show?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, private_published_post).show?).to be true
    end

    it 'allows the creator (even for drafts/private posts)' do
      expect(described_class.new(creator_user, draft_post).show?).to be true
      expect(described_class.new(creator_user, private_published_post).show?).to be true
    end

    it 'allows published public posts for regular users' do
      expect(described_class.new(regular_user, public_published_post).show?).to be true
    end

    it 'denies published private posts for other regular users' do
      expect(described_class.new(regular_user, private_published_post).show?).to be false
    end

    it 'denies draft posts for unauthenticated users' do
      expect(described_class.new(nil, draft_post).show?).to be false
    end

    it 'denies published private posts for unauthenticated users' do
      expect(described_class.new(nil, private_published_post).show?).to be false
    end

    it 'denies posts authored by blocked people' do
      blocked_author_user = create(:better_together_user, :confirmed)
      blocked_post = create(
        :better_together_post,
        creator: blocked_author_user.person,
        author: blocked_author_user.person,
        privacy: 'public',
        published_at: 1.minute.ago
      )

      create(:person_block, blocker: regular_user.person, blocked: blocked_author_user.person)

      expect(described_class.new(regular_user, blocked_post).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, BetterTogether::Post).create?).to be true
    end

    it 'denies regular users' do
      expect(described_class.new(regular_user, BetterTogether::Post).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, BetterTogether::Post)).not_to be_create
    end
  end

  describe '#update?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, public_published_post).update?).to be true
    end

    it 'denies regular users' do
      expect(described_class.new(regular_user, public_published_post).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, public_published_post).destroy?).to be true
    end

    it 'denies regular users' do
      expect(described_class.new(regular_user, public_published_post).destroy?).to be false
    end
  end

  describe 'Scope' do
    let!(:manager_draft) do
      create(
        :better_together_post,
        creator: platform_manager_user.person,
        author: platform_manager_user.person,
        privacy: 'private',
        published_at: nil
      )
    end

    let!(:creator_private_published) { private_published_post }
    let!(:creator_public_published) { public_published_post }

    let!(:blocked_author_user) { create(:better_together_user, :confirmed) }
    let!(:blocked_public_post) do
      create(
        :better_together_post,
        creator: blocked_author_user.person,
        author: blocked_author_user.person,
        privacy: 'public',
        published_at: 1.minute.ago
      )
    end

    it 'returns all posts for platform managers' do
      scope = described_class::Scope.new(platform_manager_user, BetterTogether::Post)
      expect(scope.resolve).to include(manager_draft, creator_private_published, creator_public_published, blocked_public_post)
    end

    it 'returns only published public posts for unauthenticated users' do
      scope = described_class::Scope.new(nil, BetterTogether::Post)
      result = scope.resolve

      expect(result).to include(creator_public_published, blocked_public_post)
      expect(result).not_to include(creator_private_published)
      expect(result).not_to include(manager_draft)
    end

    it 'returns published public posts and own published posts for regular users' do
      own_published_private = create(
        :better_together_post,
        creator: regular_user.person,
        author: regular_user.person,
        privacy: 'private',
        published_at: 1.minute.ago
      )

      own_draft_public = create(
        :better_together_post,
        creator: regular_user.person,
        author: regular_user.person,
        privacy: 'public',
        published_at: nil
      )

      scope = described_class::Scope.new(regular_user, BetterTogether::Post)
      result = scope.resolve

      expect(result).to include(creator_public_published)
      expect(result).to include(own_published_private)
      expect(result).not_to include(creator_private_published)
      expect(result).not_to include(own_draft_public)
    end

    it 'excludes posts from blocked authors for regular users' do
      create(:person_block, blocker: regular_user.person, blocked: blocked_author_user.person)

      scope = described_class::Scope.new(regular_user, BetterTogether::Post)
      expect(scope.resolve).not_to include(blocked_public_post)
    end
  end
end
