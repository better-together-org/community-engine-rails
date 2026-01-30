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

    it 'has ActionTool::Base alias' do
      expect(BetterTogether::ActionTool::Base).to eq(described_class)
    end
  end

  describe '#pundit_user' do
    let(:user) { create(:user) }
    let(:context) { BetterTogether::Mcp::PunditContext.new(user: user) }
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
      # Stub the request context to provide our user
      allow_any_instance_of(tool_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
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
      allow_any_instance_of(tool_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
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
      allow_any_instance_of(tool_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
    end

    it 'returns person from user' do
      tool = tool_class.new

      expect(tool.call).to eq(user.person)
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
      allow_any_instance_of(tool_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
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
