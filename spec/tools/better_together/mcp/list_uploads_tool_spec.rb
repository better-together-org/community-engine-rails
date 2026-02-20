# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ListUploadsTool, type: :model do
  let(:user) { create(:user) }
  let(:person) { user.person }
  let!(:own_upload) { create(:better_together_upload, creator: person) }
  let!(:other_upload) { create(:better_together_upload, creator: create(:better_together_person)) }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('upload')
    end
  end

  describe '#call' do
    it 'returns own uploads only' do
      tool = described_class.new
      result = JSON.parse(tool.call)

      ids = result.map { |u| u['id'] }
      expect(ids).to include(own_upload.id)
      expect(ids).not_to include(other_upload.id)
    end

    it 'returns upload attributes' do
      tool = described_class.new
      result = JSON.parse(tool.call)
      next if result.empty?

      upload = result.first
      expect(upload).to have_key('id')
      expect(upload).to have_key('name')
    end

    it 'respects limit parameter' do
      3.times { create(:better_together_upload, creator: person) }
      tool = described_class.new
      result = JSON.parse(tool.call(limit: 2))

      expect(result.length).to be <= 2
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns authentication error for anonymous users' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to have_key('error')
        expect(result['error']).to include('Authentication')
      end
    end
  end
end
