# frozen_string_literal: true

require 'rails_helper'

# An agent credential limited to community A must not see community B through
# any MCP tool, even for records the operator created or belongs to.
RSpec.describe 'MCP tools under a community-limited credential', type: :model do
  let(:operator_user) { create(:user, :confirmed, :platform_manager) }
  let!(:community_a) { create(:community, name: 'Community A', privacy: 'public') }
  let!(:community_b) { create(:community, name: 'Community B', privacy: 'private', creator: operator_user.person) }
  let!(:post_a) { create(:post, community: community_a, privacy: 'public', title: 'Post in A') }
  let!(:post_b) do
    create(:post, community: community_b, privacy: 'private', creator: operator_user.person, title: 'Post in B')
  end

  before do
    configure_host_platform
    Current.credential_community = community_a
  end

  after { Current.reset }

  it 'lists only the credential community' do
    stub_mcp_request_for(BetterTogether::Mcp::ListCommunitiesTool, user: operator_user)

    names = JSON.parse(BetterTogether::Mcp::ListCommunitiesTool.new.call).map { |c| c['name'] }

    expect(names).to contain_exactly('Community A')
  end

  it 'searches only posts of the credential community' do
    stub_mcp_request_for(BetterTogether::Mcp::SearchPostsTool, user: operator_user)

    result = BetterTogether::Mcp::SearchPostsTool.new.call(query: 'Post')

    expect(result).to include('Post in A')
    expect(result).not_to include('Post in B')
  end

  it 'cannot fetch a post of another community' do
    stub_mcp_request_for(BetterTogether::Mcp::GetPostTool, user: operator_user)

    result = BetterTogether::Mcp::GetPostTool.new.call(post_id: post_b.id)

    expect(result).not_to include('Post in B')
  end
end
