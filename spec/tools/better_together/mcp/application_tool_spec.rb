# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ApplicationTool, type: :model do
  describe 'class inheritance' do
    it 'inherits from FastMcp::Tool' do
      expect(described_class).to be < FastMcp::Tool
    end

    it 'includes Pundit::Authorization' do
      expect(described_class.included_modules).to include(Pundit::Authorization)
    end

    it 'includes PunditIntegration concern' do
      expect(described_class.included_modules).to include(BetterTogether::Mcp::PunditIntegration)
    end

    it 'has ActionTool::Base alias' do
      expect(BetterTogether::ActionTool::Base).to eq(described_class)
    end
  end

  # Verify RBAC tags are correctly applied to every concrete tool class.
  # Tags drive the 3-tier filter in config/initializers/fast_mcp.rb:
  #   :public        → visible to guests
  #   :authenticated → visible to signed-in users (hidden from guests)
  #   :admin         → visible only to users with manage_platform permission
  describe 'tool RBAC tag classification' do
    let(:all_tools) { described_class.descendants }

    before { Rails.application.eager_load! }

    it 'every concrete tool declares exactly one RBAC tag' do
      all_tools.each do |tool_class|
        tags = tool_class.tags
        rbac_tags = tags & %i[public authenticated admin]
        expect(rbac_tags.length).to eq(1),
                                    "#{tool_class.name} must declare exactly one of :public/:authenticated/:admin, got: #{tags.inspect}"
      end
    end

    describe ':admin tools (require manage_platform permission)' do
      subject(:admin_tools) { all_tools.select { |t| t.tags.include?(:admin) } }

      it 'includes GetMetricsSummaryTool' do
        expect(admin_tools).to include(BetterTogether::Mcp::GetMetricsSummaryTool)
      end
    end

    describe ':authenticated tools (require signed-in user)' do
      subject(:auth_tools) { all_tools.select { |t| t.tags.include?(:authenticated) } }

      it 'includes all write tools' do
        expect(auth_tools).to include(
          BetterTogether::Mcp::CreatePostTool,
          BetterTogether::Mcp::CreateEventTool,
          BetterTogether::Mcp::SendMessageTool
        )
      end

      it 'includes user-scoped read tools' do
        expect(auth_tools).to include(
          BetterTogether::Mcp::ListConversationsTool,
          BetterTogether::Mcp::ListInvitationsTool,
          BetterTogether::Mcp::ListNotificationsTool,
          BetterTogether::Mcp::ListUploadsTool
        )
      end
    end

    describe ':public tools (accessible to guests)' do
      subject(:public_tools) { all_tools.select { |t| t.tags.include?(:public) } }

      it 'includes public read/search tools' do
        expect(public_tools).to include(
          BetterTogether::Mcp::ListCommunitiesTool,
          BetterTogether::Mcp::ListEventsTool,
          BetterTogether::Mcp::GetEventDetailTool,
          BetterTogether::Mcp::GetPostTool,
          BetterTogether::Mcp::SearchPostsTool,
          BetterTogether::Mcp::SearchGeographyTool,
          BetterTogether::Mcp::SearchPeopleTool,
          BetterTogether::Mcp::ListPagesTool,
          BetterTogether::Mcp::SearchPagesTool,
          BetterTogether::Mcp::ListOffersTool,
          BetterTogether::Mcp::ListRequestsTool,
          BetterTogether::Mcp::ManageNavigationTool
        )
      end
    end
  end

  describe '#pundit_user' do
    let(:user) { create(:user) }
    let(:tool_class) do
      Class.new(described_class) do
        description 'Test tool'

        def call
          'executed'
        end
      end
    end

    before do
      configure_host_platform
      stub_mcp_request_for(tool_class, user: user)
    end

    it 'returns PunditContext from request' do
      tool = tool_class.new

      expect(tool.send(:pundit_user)).to be_a(BetterTogether::Mcp::PunditContext)
      expect(tool.send(:pundit_user).user).to eq(user)
    end
  end

  describe '#current_user' do
    let(:user) { create(:user) }
    let(:tool_class) do
      Class.new(described_class) do
        description 'Test tool'

        def call
          current_user
        end
      end
    end

    before do
      configure_host_platform
      stub_mcp_request_for(tool_class, user: user)
    end

    it 'returns user from pundit context' do
      tool = tool_class.new

      expect(tool.call).to eq(user)
    end
  end

  describe '#agent' do
    let(:user) { create(:user) }
    let(:tool_class) do
      Class.new(described_class) do
        description 'Test tool'

        def call
          agent
        end
      end
    end

    before do
      configure_host_platform
      stub_mcp_request_for(tool_class, user: user)
    end

    it 'returns person from user' do
      tool = tool_class.new

      expect(tool.call).to eq(user.person)
    end
  end

  describe 'anonymous access' do
    let(:tool_class) do
      Class.new(described_class) do
        description 'Test tool'

        def call
          current_user
        end
      end
    end

    before do
      configure_host_platform
      stub_mcp_request_for(tool_class, user: nil)
    end

    it 'returns nil for anonymous requests' do
      tool = tool_class.new

      expect(tool.call).to be_nil
    end
  end

  describe 'authorization enforcement' do
    let(:user) { create(:user) }
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
    let(:community) { create(:community, privacy: 'private') }
    let(:tool_class) do
      Class.new(described_class) do
        description 'Test authorization tool'

        arguments do
          required(:community_id).filled(:string)
        end

        def call(community_id:)
          community = BetterTogether::Community.find(community_id)
          authorize community, :show?
          community.name
        end
      end
    end

    before do
      configure_host_platform
      stub_mcp_request_for(tool_class, user: user)
    end

    context 'when user has permission' do
      let(:community_role) { create(:role, :community_role) }

      before do
        # Make user a member of the community
        community.person_community_memberships.find_or_create_by!(member: user.person) do |membership|
          membership.role = community_role
        end

        # Make user a platform manager
        platform_manager_permission = BetterTogether::ResourcePermission.find_or_create_by!(
          identifier: 'manage_platform'
        ) do |permission|
          permission.resource_type = 'BetterTogether::Platform'
          permission.action = 'manage'
          permission.target = 'platform'
        end
        platform_manager_role = BetterTogether::Role.find_or_create_by!(
          identifier: "platform_manager_#{SecureRandom.hex(4)}",
          resource_type: 'BetterTogether::Platform'
        ) do |role|
          role.name = 'Platform Manager'
        end
        platform_manager_role.role_resource_permissions.find_or_create_by!(resource_permission: platform_manager_permission)
        host_platform.person_platform_memberships.find_or_create_by!(member: user.person) do |member|
          member.role = platform_manager_role
        end
      end

      it 'executes successfully' do
        tool = tool_class.new

        result = tool.call(community_id: community.id)

        expect(result).to eq(community.name)
      end
    end

    context 'when user lacks permission' do
      it 'raises Pundit::NotAuthorizedError' do
        tool = tool_class.new

        expect do
          tool.call(community_id: community.id)
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end
