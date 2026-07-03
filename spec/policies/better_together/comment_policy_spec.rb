# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CommentPolicy do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:creator_user) { create(:better_together_user, :confirmed) }
  let(:scoped_community) { create(:better_together_community, privacy: 'public') }
  let(:scoped_platform) { create(:better_together_platform, community: scoped_community) }
  let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:host_community) { host_platform.community }

  let(:public_post) do
    create(:better_together_post, creator: creator_user.person, author: creator_user.person,
                                  privacy: 'public', published_at: 1.minute.ago)
  end

  let(:comment) { create(:comment, creator: creator_user.person, commentable: public_post) }

  before do
    membership = BetterTogether::PersonCommunityMembership.find_or_create_by!(
      joinable: host_community, member: regular_user.person, role: community_member_role
    )
    membership.update!(status: 'active') unless membership.active?
  end

  describe '#show?' do
    it "delegates to the commentable's own show? policy" do
      expect(described_class.new(regular_user, comment).show?).to be true
    end
  end

  describe '#create?' do
    it 'allows a signed-in user who can view the commentable' do
      new_comment = BetterTogether::Comment.new(commentable: public_post)
      expect(described_class.new(regular_user, new_comment).create?).to be true
    end

    it 'denies unauthenticated users' do
      new_comment = BetterTogether::Comment.new(commentable: public_post)
      expect(described_class.new(nil, new_comment)).not_to be_create
    end

    it 'denies a user blocked by the commentable creator' do
      create(:person_block, blocker: creator_user.person, blocked: regular_user.person)
      new_comment = BetterTogether::Comment.new(commentable: public_post)

      expect(described_class.new(regular_user, new_comment).create?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows the comment creator' do
      expect(described_class.new(creator_user, comment).destroy?).to be true
    end

    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, comment).destroy?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, comment).destroy?).to be false
    end

    it 'allows a community content manager for the commentable community' do
      role = create(:better_together_role, :community_role)
      permission = BetterTogether::ResourcePermission.find_by!(identifier: 'manage_community_content')
      role.assign_resource_permissions([permission.identifier])
      BetterTogether::PersonCommunityMembership.find_by!(
        joinable: host_community, member: regular_user.person
      ).update!(role: role)

      host_post = create(:better_together_post, creator: creator_user.person, author: creator_user.person,
                                                community: host_community, privacy: 'public',
                                                published_at: 1.minute.ago)
      host_comment = create(:comment, creator: creator_user.person, commentable: host_post)

      expect(described_class.new(regular_user, host_comment).destroy?).to be true
    end
  end

  describe 'Scope' do
    it 'excludes comments from people the requesting agent has blocked' do
      blocked_user = create(:better_together_user, :confirmed)
      blocked_comment = create(:comment, creator: blocked_user.person, commentable: public_post)
      create(:person_block, blocker: regular_user.person, blocked: blocked_user.person)

      scope = described_class::Scope.new(regular_user, BetterTogether::Comment)

      expect(scope.resolve).not_to include(blocked_comment)
    end

    it 'orders comments oldest first' do
      first = create(:comment, commentable: public_post, created_at: 2.minutes.ago)
      second = create(:comment, commentable: public_post, created_at: 1.minute.ago)

      scope = described_class::Scope.new(regular_user, BetterTogether::Comment)

      expect(scope.resolve.where(id: [first.id, second.id]).to_a).to eq([first, second])
    end
  end
end
