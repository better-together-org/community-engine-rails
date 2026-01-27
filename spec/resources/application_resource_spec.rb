# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ApplicationResource, type: :model do
  describe 'class inheritance' do
    it 'inherits from FastMcp::Resource' do
      expect(described_class).to be < FastMcp::Resource
    end

    it 'includes Pundit::Authorization' do
      expect(described_class.included_modules).to include(Pundit::Authorization)
    end

    it 'has ActionResource::Base alias' do
      expect(BetterTogether::ActionResource::Base).to eq(described_class)
    end
  end

  describe '#pundit_user' do
    let(:user) { create(:user) }
    let(:resource_class) do
      Class.new(described_class) do
        uri 'test://resource'
        resource_name 'Test Resource'
        mime_type 'application/json'

        def content
          JSON.generate({ test: 'data' })
        end
      end
    end

    before do
      configure_host_platform
      allow_any_instance_of(resource_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
    end

    it 'returns PunditContext from request' do
      resource = resource_class.new

      expect(resource.send(:pundit_user)).to be_a(BetterTogether::Mcp::PunditContext)
      expect(resource.send(:pundit_user).user).to eq(user)
    end
  end

  describe '#current_user' do
    let(:user) { create(:user) }
    let(:resource_class) do
      Class.new(described_class) do
        uri 'test://resource'
        resource_name 'Test Resource'
        mime_type 'application/json'

        def content
          JSON.generate({ user_id: current_user&.id })
        end
      end
    end

    before do
      configure_host_platform
      allow_any_instance_of(resource_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
    end

    it 'returns user from pundit context' do
      resource = resource_class.new
      content = JSON.parse(resource.content)

      expect(content['user_id']).to eq(user.id)
    end
  end

  describe 'privacy scoping with policy_scope' do
    let(:public_community) { create(:community, privacy: 'public') }
    let(:private_community) { create(:community, privacy: 'private') }
    let(:user) { create(:user) }
    let(:resource_class) do
      Class.new(described_class) do
        uri 'bettertogether://communities'
        resource_name 'Communities'
        mime_type 'application/json'

        def content
          communities = policy_scope(BetterTogether::Community)
          JSON.generate(communities.map { |c| { id: c.id, name: c.name } })
        end
      end
    end

    before do
      configure_host_platform
    end

    context 'when user is authenticated' do
      before do
        allow_any_instance_of(resource_class).to receive(:request).and_return(
          instance_double(Rack::Request, params: { 'user_id' => user.id })
        )
      end

      it 'returns only public communities for regular user' do
        public_community
        private_community

        resource = resource_class.new
        content = JSON.parse(resource.content)

        community_ids = content.map { |c| c['id'] }
        expect(community_ids).to include(public_community.id)
        expect(community_ids).not_to include(private_community.id)
      end

      context 'when user is platform manager' do
        let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

        before do
          platform_manager_permission = BetterTogether::ResourcePermission.find_or_create_by!(
            identifier: 'bt_manage_platform',
            resource_type: 'BetterTogether::Platform',
            action: 'manage',
            target: 'platform'
          )
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

        it 'returns all communities' do
          public_community
          private_community

          resource = resource_class.new
          content = JSON.parse(resource.content)

          community_ids = content.map { |c| c['id'] }
          expect(community_ids).to include(public_community.id, private_community.id)
        end
      end
    end

    context 'when user is not authenticated' do
      before do
        allow_any_instance_of(resource_class).to receive(:request).and_return(
          instance_double(Rack::Request, params: {})
        )
      end

      it 'returns only public communities' do
        public_community
        private_community

        resource = resource_class.new
        content = JSON.parse(resource.content)

        community_ids = content.map { |c| c['id'] }
        expect(community_ids).to include(public_community.id)
        expect(community_ids).not_to include(private_community.id)
      end
    end
  end

  describe 'blocked users filtering' do
    let(:user) { create(:user) }
    let(:blocked_user) { create(:user) }
    let(:user_post) { create(:post, creator: user.person, privacy: 'public', published_at: Time.current) }
    let(:blocked_post) do
      create(:post, creator: blocked_user.person, privacy: 'public', published_at: Time.current)
    end
    let(:resource_class) do
      Class.new(described_class) do
        uri 'bettertogether://posts'
        resource_name 'Posts'
        mime_type 'application/json'

        def content
          posts = policy_scope(BetterTogether::Post)
          JSON.generate(posts.map { |p| { id: p.id, creator_id: p.creator_id } })
        end
      end
    end

    before do
      configure_host_platform
      create(:person_block, blocker: user.person, blocked: blocked_user.person)
      allow_any_instance_of(resource_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
    end

    it 'excludes posts from blocked users' do
      # Explicitly create posts
      user_post
      blocked_post

      resource = resource_class.new
      content = JSON.parse(resource.content)

      creator_ids = content.map { |p| p['creator_id'] }
      expect(creator_ids).to include(user.person.id)
      expect(creator_ids).not_to include(blocked_user.person.id)
    end
  end
end
