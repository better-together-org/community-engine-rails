# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Content Blocks' do
  describe 'POST /content/blocks' do
    let(:user) { create(:better_together_user, :confirmed, :platform_manager) }

    before do
      login(user.email, 'SecureTest123!@#')
    end

    it 'attaches existing blob when media_signed_id is provided' do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('fake image'),
        filename: 'test.png',
        content_type: 'image/png'
      )

      expect do
        post better_together.content_blocks_path, params: {
          block: {
            type: 'BetterTogether::Content::Image',
            media_signed_id: blob.signed_id
          }
        }
      end.to change(BetterTogether::Content::Image, :count).by(1)

      block = BetterTogether::Content::Image.last
      expect(block.media).to be_attached
      expect(block.media.blob).to eq(blob)
    end
  end

  describe 'PATCH /content/blocks/:id' do
    let(:user) { create(:better_together_user, :confirmed, :platform_manager) }
    let(:block) { create(:better_together_content_image) }

    before do
      login(user.email, 'SecureTest123!@#')
    end

    it 'redirects successfully for html requests' do
      patch better_together.content_block_path(block), params: {
        block: {
          alt_text_en: 'Updated alt text'
        }
      }

      expect(response).to redirect_to(better_together.content_block_path(block))
      expect(block.reload.alt_text).to eq('Updated alt text')
    end
  end
end
