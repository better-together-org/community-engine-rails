# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::PublicCommunitiesResource, type: :model do
  let(:public_community1) { create(:community, name: 'Public One', privacy: 'public') }
  let(:public_community2) { create(:community, name: 'Public Two', privacy: 'public') }
  let(:private_community) { create(:community, name: 'Private', privacy: 'private') }

  before do
    configure_host_platform
  end

  describe '.uri' do
    it 'has correct URI pattern' do
      expect(described_class.uri).to eq('bettertogether://communities/public')
    end
  end

  describe '.resource_name' do
    it 'has descriptive name' do
      expect(described_class.resource_name).to eq('Public Communities')
    end
  end

  describe '.mime_type' do
    it 'returns JSON' do
      expect(described_class.mime_type).to eq('application/json')
    end
  end

  describe '#content' do
    context 'when unauthenticated' do
      before do
        # Explicitly create communities for this test
        public_community1
        public_community2
        private_community

        allow_any_instance_of(described_class).to receive(:request).and_return(
          instance_double(Rack::Request, params: {})
        )
      end

      it 'returns only public communities' do
        resource = described_class.new
        content = JSON.parse(resource.content)

        names = content['communities'].map { |c| c['name'] }
        expect(names).to include('Public One', 'Public Two')
        expect(names).not_to include('Private')
      end
    end

    context 'when authenticated as regular user' do
      let(:user) { create(:user) }

      before do
        # Explicitly create communities for this test
        public_community1
        public_community2
        private_community

        allow_any_instance_of(described_class).to receive(:request).and_return(
          instance_double(Rack::Request, params: { 'user_id' => user.id })
        )
      end

      it 'returns only public communities' do
        resource = described_class.new
        content = JSON.parse(resource.content)

        names = content['communities'].map { |c| c['name'] }
        expect(names).to include('Public One', 'Public Two')
        expect(names).not_to include('Private')
      end
    end

    it 'includes community details' do
      # Explicitly create communities for this test
      public_community1

      allow_any_instance_of(described_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: {})
      )

      resource = described_class.new
      content = JSON.parse(resource.content)
      community = content['communities'].first

      expect(community).to have_key('id')
      expect(community).to have_key('name')
      expect(community).to have_key('description')
      expect(community).to have_key('slug')
      expect(community).to have_key('member_count')
    end
  end
end
