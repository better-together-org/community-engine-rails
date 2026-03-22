# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::DeletePageBlockTool, type: :model do
  let(:manager_user) { create(:user, :platform_manager) }
  let(:page) { create(:better_together_page, :published_public) }

  before do
    configure_host_platform
  end

  describe '#call' do
    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns an authentication error' do
        result = JSON.parse(described_class.new.call(page_block_id: SecureRandom.uuid))

        expect(result['error']).to eq('Authentication required')
      end
    end

    context 'when authenticated as a platform manager' do
      before { stub_mcp_request_for(described_class, user: manager_user) }

      it 'detaches the page block without destroying the block by default' do
        block = create(:content_markdown, :simple)
        page_block = create(:better_together_content_page_block, page: page, block: block, position: 0)

        expect do
          result = JSON.parse(described_class.new.call(page_block_id: page_block.id))

          expect(result['page_block_id']).to eq(page_block.id)
          expect(result['block_id']).to eq(block.id)
          expect(result['block_destroyed']).to be(false)
        end.to change(BetterTogether::Content::PageBlock, :count).by(-1)

        expect(BetterTogether::Content::Block.find_by(id: block.id)).to be_present
      end

      it 'destroys the block when requested and no other pages reference it' do
        block = create(:content_markdown, :simple)
        page_block = create(:better_together_content_page_block, page: page, block: block, position: 0)

        expect do
          result = JSON.parse(described_class.new.call(page_block_id: page_block.id, destroy_block: true))

          expect(result['page_block_id']).to eq(page_block.id)
          expect(result['block_id']).to eq(block.id)
          expect(result['block_destroyed']).to be(true)
        end.to change(BetterTogether::Content::PageBlock, :count).by(-1)
                                                                 .and change(BetterTogether::Content::Block, :count).by(-1)
      end

      it 'keeps the block when it is still attached elsewhere' do
        block = create(:content_markdown, :simple)
        first_page_block = create(:better_together_content_page_block, page: page, block: block, position: 0)
        other_page = create(:better_together_page, :published_public)
        create(:better_together_content_page_block, page: other_page, block: block, position: 1)

        expect do
          result = JSON.parse(described_class.new.call(page_block_id: first_page_block.id, destroy_block: true))

          expect(result['error']).to include('Detached from this page only.')
          expect(result['block_id']).to eq(block.id)
        end.to change(BetterTogether::Content::PageBlock, :count).by(-1)

        expect(BetterTogether::Content::Block.find_by(id: block.id)).to be_present
      end
    end
  end
end
