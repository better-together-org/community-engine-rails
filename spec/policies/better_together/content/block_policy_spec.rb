# frozen_string_literal: true

require 'rails_helper'

# Instance methods added via `include` survive rspec-rebound's example wrapper,
# unlike a bare `def` inside a nested `describe`.
module BlockPolicySpecHelpers
  def build_block_on(page_privacy:, published:, block_privacy:)
    page = create(:better_together_page, privacy: page_privacy,
                                         published_at: published ? 1.day.ago : nil)
    blk = create(:content_markdown)
    blk.update_columns(privacy: block_privacy)
    create(:page_content_block, page: page, block: blk)
    [page, blk]
  end
end

RSpec.describe BetterTogether::Content::BlockPolicy, type: :policy do
  include BlockPolicySpecHelpers

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

  describe '#create? / #update? / #destroy?' do
    %i[create? update? destroy?].each do |action|
      it "#{action} is true for a platform manager, false otherwise" do
        expect(described_class.new(manager_user, block).public_send(action)).to be true
        expect(described_class.new(normal_user, block).public_send(action)).to be false
        expect(described_class.new(nil, block).public_send(action)).to be false
      end
    end
  end

  describe '#new? / #edit?' do
    it 'delegate to create? / update?' do
      policy = described_class.new(manager_user, block)
      expect(policy.new?).to eq(policy.create?)
      expect(policy.edit?).to eq(policy.update?)
    end
  end

  describe '#preview_markdown?' do
    it { expect(described_class.new(normal_user, block).preview_markdown?).to be true }
    it { expect(described_class.new(manager_user, block).preview_markdown?).to be true }
    it { expect(described_class.new(nil, block).preview_markdown?).to be false }
  end

  describe '#show? / #download? — visibility gating' do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
    let(:host_community) { host_platform.community }

    let(:community_member) do
      user = create(:better_together_user)
      create(:better_together_person_community_membership, joinable: host_community, member: user.person)
      user
    end

    it 'aliases download? to show?' do
      _page, blk = build_block_on(page_privacy: 'public', published: true, block_privacy: 'public')
      policy = described_class.new(nil, blk)
      expect(policy.download?).to eq(policy.show?)
    end

    context 'block on a published public page' do
      it 'public block: visible to everyone' do
        _page, blk = build_block_on(page_privacy: 'public', published: true, block_privacy: 'public')
        expect(described_class.new(nil, blk).show?).to be true
        expect(described_class.new(normal_user, blk).show?).to be true
        expect(described_class.new(manager_user, blk).show?).to be true
      end

      it 'community block: only community members + managers' do
        _page, blk = build_block_on(page_privacy: 'public', published: true, block_privacy: 'community')
        expect(described_class.new(nil, blk).show?).to be false
        expect(described_class.new(normal_user, blk).show?).to be false
        expect(described_class.new(community_member, blk).show?).to be true
        expect(described_class.new(manager_user, blk).show?).to be true
      end

      it 'private block: only managers and the block creator' do
        _page, blk = build_block_on(page_privacy: 'public', published: true, block_privacy: 'private')
        expect(described_class.new(nil, blk).show?).to be false
        expect(described_class.new(normal_user, blk).show?).to be false
        expect(described_class.new(community_member, blk).show?).to be false
        expect(described_class.new(manager_user, blk).show?).to be true

        blk.update_columns(creator_id: normal_user.person.id)
        expect(described_class.new(normal_user, blk).show?).to be true
      end

      it 'private block: visible to a page contributor' do
        page, blk = build_block_on(page_privacy: 'public', published: true, block_privacy: 'private')
        contributor = create(:better_together_user)
        page.contributions.create!(author: contributor.person, role: BetterTogether::Authorship::EDITOR_ROLE,
                                   contribution_type: BetterTogether::Authorship::CONTENT_CONTRIBUTION)
        expect(described_class.new(contributor, blk).show?).to be true
      end
    end

    context 'block bounded by its page' do
      it 'a public block on an unpublished page is not visible to the public' do
        _page, blk = build_block_on(page_privacy: 'public', published: false, block_privacy: 'public')
        expect(described_class.new(nil, blk).show?).to be false
        expect(described_class.new(manager_user, blk).show?).to be true
      end

      it 'a public block on a private page is not visible to the public' do
        _page, blk = build_block_on(page_privacy: 'private', published: true, block_privacy: 'public')
        expect(described_class.new(nil, blk).show?).to be false
        expect(described_class.new(normal_user, blk).show?).to be false
      end
    end

    it 'gates a Content::Template block by its own privacy, like any other block' do
      page = create(:better_together_page, privacy: 'public', published_at: 1.day.ago)
      template = create(:content_template)
      template.update_columns(privacy: 'private')
      create(:page_content_block, page: page, block: template)

      expect(described_class.new(nil, template).show?).to be false
      expect(described_class.new(manager_user, template).show?).to be true

      template.update_columns(privacy: 'public')
      expect(described_class.new(nil, template).show?).to be true
      expect(described_class.new(nil, template).download?).to be true
    end

    it 'a block with no page assignment is treated as visible chrome (subject to its own privacy)' do
      public_orphan = create(:content_markdown)
      public_orphan.update_columns(privacy: 'public')
      expect(described_class.new(nil, public_orphan).show?).to be true

      private_orphan = create(:content_markdown)
      private_orphan.update_columns(privacy: 'private')
      expect(described_class.new(nil, private_orphan).show?).to be false
    end
  end

  describe 'Scope' do
    subject(:scope) { described_class::Scope.new(user, BetterTogether::Content::Block).resolve }

    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
    let!(:public_block) { create(:content_markdown).tap { |b| b.update_columns(privacy: 'public') } }
    let!(:community_block) { create(:content_markdown).tap { |b| b.update_columns(privacy: 'community') } }
    let!(:private_block) { create(:better_together_content_html).tap { |b| b.update_columns(privacy: 'private') } }

    context 'when user is a platform manager' do
      let(:user) { manager_user }

      it 'returns all blocks ordered by created_at DESC and preloads pages' do
        expect(scope).to include(public_block, community_block, private_block)
        expect(scope.first.created_at).to be >= scope.last.created_at
        expect(scope.first.association(:pages)).to be_loaded
      end
    end

    context 'when the viewer is anonymous' do
      let(:user) { nil }

      it 'returns only public blocks' do
        expect(scope).to include(public_block)
        expect(scope).not_to include(community_block, private_block)
      end
    end

    context 'when the viewer is a signed-in non-member' do
      let(:user) { normal_user }

      it 'returns public blocks and the viewer\'s own blocks' do
        own = create(:content_markdown)
        own.update_columns(privacy: 'private', creator_id: normal_user.person.id)

        expect(scope).to include(public_block, own)
        expect(scope).not_to include(community_block, private_block)
      end
    end

    context 'when the viewer is a member of the platform community' do
      let(:user) do
        u = create(:better_together_user)
        create(:better_together_person_community_membership, joinable: host_platform.community, member: u.person)
        u
      end

      it 'returns public and community blocks' do
        expect(scope).to include(public_block, community_block)
        expect(scope).not_to include(private_block)
      end
    end
  end
end
