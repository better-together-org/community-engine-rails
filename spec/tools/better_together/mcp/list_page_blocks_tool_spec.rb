# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ListPageBlocksTool, type: :model do
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:page) { create(:better_together_page, :published_public) }

  let!(:public_block) { attach_block('public', 'PUBLIC-MCP') }
  let!(:community_block) { attach_block('community', 'COMMUNITY-MCP') }
  let!(:private_block) { attach_block('private', 'PRIVATE-MCP') }

  before { configure_host_platform }

  def attach_block(privacy, token)
    block = create(:content_markdown, markdown_source: token)
    block.update_columns(privacy: privacy)
    create(:better_together_content_page_block, page: page, block: block, position: page.page_blocks.count)
    block
  end

  def block_ids_for(user)
    stub_mcp_request_for(described_class, user: user)
    result = JSON.parse(described_class.new.call(page_id: page.id))
    result.fetch('blocks').map { |b| b['block_id'] }
  end

  it 'returns every block to a platform manager' do
    manager = create(:better_together_user, :confirmed, :platform_manager)

    expect(block_ids_for(manager)).to contain_exactly(public_block.id, community_block.id, private_block.id)
  end

  it 'returns only the public block to an anonymous caller' do
    expect(block_ids_for(nil)).to contain_exactly(public_block.id)
  end

  it 'returns only the public block to a signed-in non-member' do
    expect(block_ids_for(create(:better_together_user, :confirmed))).to contain_exactly(public_block.id)
  end

  it 'returns public and community blocks to a member of the platform community' do
    member = create(:better_together_user, :confirmed)
    BetterTogether::PersonCommunityMembership.create!(
      joinable: host_platform.community, member: member.person,
      role: BetterTogether::Role.find_by(identifier: 'community_member'), status: 'active'
    )

    expect(block_ids_for(member)).to contain_exactly(public_block.id, community_block.id)
  end
end
