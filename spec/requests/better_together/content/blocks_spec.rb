# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Content Blocks', type: :request do
  describe 'POST /content/blocks' do
    let(:user) { create(:better_together_user, :confirmed, :platform_manager) }

    before do
      login(user)
    end

    it 'attaches existing blob when media_signed_id is provided' do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('fake image'),
        filename: 'test.png',
        content_type: 'image/png'
      )

      expect {
        post better_together.content_blocks_path, params: {
          block: {
            type: 'BetterTogether::Content::Image',
            media_signed_id: blob.signed_id
          }
        }
      }.to change(BetterTogether::Content::Image, :count).by(1)

      block = BetterTogether::Content::Image.last
      expect(block.media).to be_attached
      expect(block.media.blob).to eq(blob)
    end
  end
end
