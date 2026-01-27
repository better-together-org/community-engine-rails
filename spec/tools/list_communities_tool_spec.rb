# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ListCommunitiesTool, type: :model do
  let(:public_community) { create(:community, name: 'Public Community', privacy: 'public') }
  let(:private_community) { create(:community, name: 'Private Community', privacy: 'private') }
  let(:user) { create(:user) }

  before do
    configure_host_platform
    allow_any_instance_of(described_class).to receive(:request).and_return(
      instance_double(Rack::Request, params: { 'user_id' => user.id })
    )
  end

  describe '.description' do
    it 'has helpful description' do
      expect(described_class.description).to include('List communities')
    end
  end

  describe '.name' do
    it 'has correct name' do
      expect(described_class.name).to be_present
    end
  end

  describe '#call' do
    context 'when user is not authenticated' do
      before do
        public_community
        private_community

        allow_any_instance_of(described_class).to receive(:request).and_return(
          instance_double(Rack::Request, params: {})
        )
      end

      it 'returns only public communities' do
        tool = described_class.new
        result = tool.call

        communities = JSON.parse(result)
        community_names = communities.map { |c| c['name'] }
        expect(community_names).to include('Public Community')
        expect(community_names).not_to include('Private Community')
      end
    end

    context 'when user is authenticated as regular user' do
      before do
        public_community
        private_community
      end

      it 'returns only public communities' do
        tool = described_class.new
        result = tool.call

        communities = JSON.parse(result)
        community_names = communities.map { |c| c['name'] }
        expect(community_names).to include('Public Community')
        expect(community_names).not_to include('Private Community')
      end
    end

    context 'when user is platform manager' do
      let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

      before do
        public_community
        private_community

        platform_manager_permission = BetterTogether::ResourcePermission.find_or_create_by!(
          identifier: 'manage_platform'
        ) do |perm|
          perm.resource_type = 'BetterTogether::Platform'
          perm.action = 'manage'
          perm.target = 'platform'
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

      it 'returns all communities' do
        tool = described_class.new
        result = tool.call

        communities = JSON.parse(result)

        names = communities.map { |c| c['name'] }
        expect(names).to include('Public Community', 'Private Community')
      end

      context 'with privacy_filter parameter' do
        it 'filters by public privacy' do
          tool = described_class.new
          result = tool.call(privacy_filter: 'public')

          communities = JSON.parse(result)
          names = communities.map { |c| c['name'] }
          expect(names).to include('Public Community')
          expect(names).not_to include('Private Community')
        end

        it 'filters by private privacy' do
          tool = described_class.new
          result = tool.call(privacy_filter: 'private')

          communities = JSON.parse(result)
          names = communities.map { |c| c['name'] }
          expect(names).to include('Private Community')
          expect(names).not_to include('Public Community')
        end
      end
    end

    it 'includes essential community information' do
      tool = described_class.new
      result = tool.call

      communities = JSON.parse(result)
      community = communities.first

      expect(community).to have_key('id')
      expect(community).to have_key('name')
      expect(community).to have_key('description')
      expect(community).to have_key('privacy')
      expect(community).to have_key('slug')
    end
  end
end
