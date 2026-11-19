# frozen_string_literal: true

require 'rails_helper'

# A record saved as 'public' under a platform or community that is not public
# must not be exposed to guests. The saved privacy is kept (so it can be
# released later); readers use the effective privacy instead.
RSpec.describe 'Privacy ceiling visibility' do # rubocop:disable RSpec/DescribeClass
  let!(:host_platform) { BetterTogether::Platform.find_by!(host: true) }
  let(:private_community) { create(:better_together_community, privacy: 'private', platform: host_platform) }
  let(:member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
  let(:member_user) { create(:better_together_user, :confirmed) }

  before do
    host_platform.update_columns(privacy: 'public') # rubocop:disable Rails/SkipsModelValidations
    host_platform.community.update_columns(privacy: 'public') # rubocop:disable Rails/SkipsModelValidations
    Current.platform = host_platform
    BetterTogether::PersonCommunityMembership.create!(
      joinable: private_community, member: member_user.person, role: member_role, status: 'active'
    )
  end

  after { Current.reset }

  describe 'pages in a private community on a public platform' do
    let!(:open_page) do
      create(:better_together_page, platform: host_platform, community: host_platform.community,
                                    privacy: 'public', published_at: 1.day.ago)
    end
    let!(:capped_page) do
      create(:better_together_page, platform: host_platform, community: private_community,
                                    privacy: 'public', published_at: 1.day.ago)
    end

    it 'hides the capped page from guests in the policy scope' do
      ids = BetterTogether::PagePolicy::Scope.new(nil, BetterTogether::Page).resolve.pluck(:id)

      expect(ids).to include(open_page.id)
      expect(ids).not_to include(capped_page.id)
    end

    it 'denies guests #show? on the capped page' do
      expect(BetterTogether::PagePolicy.new(nil, capped_page).show?).to be false
      expect(BetterTogether::PagePolicy.new(nil, open_page).show?).to be true
    end

    it 'still shows the capped page to members of the private community' do
      ids = BetterTogether::PagePolicy::Scope.new(member_user, BetterTogether::Page).resolve.pluck(:id)

      expect(ids).to include(capped_page.id)
      expect(BetterTogether::PagePolicy.new(member_user, capped_page).show?).to be true
    end

    it 'keeps the capped page out of the sitemap listing' do
      listed = BetterTogether::Page.for_platform(host_platform).published.privacy_public.within_privacy_ceiling

      expect(listed.pluck(:id)).to include(open_page.id)
      expect(listed.pluck(:id)).not_to include(capped_page.id)
    end
  end

  describe 'posts in a private community on a public platform' do
    let!(:open_post) do
      create(:better_together_post, platform: host_platform, community: host_platform.community,
                                    privacy: 'public', published_at: 1.minute.ago)
    end
    let!(:capped_post) do
      create(:better_together_post, platform: host_platform, community: private_community,
                                    privacy: 'public', published_at: 1.minute.ago)
    end

    it 'hides the capped post from guests but not from community members' do
      guest_ids = BetterTogether::PostPolicy::Scope.new(nil, BetterTogether::Post).resolve.pluck(:id)
      member_ids = BetterTogether::PostPolicy::Scope.new(member_user, BetterTogether::Post).resolve.pluck(:id)

      expect(guest_ids).to include(open_post.id)
      expect(guest_ids).not_to include(capped_post.id)
      expect(member_ids).to include(capped_post.id)
    end

    it 'denies guests #show? on the capped post' do
      expect(BetterTogether::PostPolicy.new(nil, capped_post).show?).to be false
    end
  end

  describe 'release: making the platform public exposes content prepared while it was private' do
    it 'shows a public page prepared under a private platform once the platform opens' do
      host_platform.update_columns(privacy: 'private') # rubocop:disable Rails/SkipsModelValidations
      host_platform.community.update_columns(privacy: 'private') # rubocop:disable Rails/SkipsModelValidations
      page = create(:better_together_page, platform: host_platform, community: host_platform.community,
                                           privacy: 'public', published_at: 1.day.ago)
      expect(BetterTogether::PagePolicy.new(nil, page).show?).to be false

      host_platform.update_columns(privacy: 'public') # rubocop:disable Rails/SkipsModelValidations
      host_platform.community.update_columns(privacy: 'public') # rubocop:disable Rails/SkipsModelValidations

      expect(BetterTogether::PagePolicy.new(nil, page.reload).show?).to be true
    end
  end
end
