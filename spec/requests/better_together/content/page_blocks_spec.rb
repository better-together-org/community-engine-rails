# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Content Page Blocks' do
  let(:user) { create(:better_together_user, :confirmed, :platform_manager) }

  before { login(user.email, 'SecureTest123!@#') }

  describe 'GET new_page_page_block_path' do
    %w[public community private].each do |page_privacy|
      it "defaults a new block's privacy to a #{page_privacy} page's privacy" do
        page = create(:better_together_page, privacy: page_privacy, published_at: 1.day.ago)

        get better_together.new_page_page_block_path(
          page.slug, block_type: 'BetterTogether::Content::Hero',
                     locale: I18n.default_locale, format: :turbo_stream
        )

        expect(response).to have_http_status(:ok)
        select_html = response.body[%r{<select[^>]*\[block_attributes\]\[privacy\][^>]*>.*?</select>}m]
        expect(select_html).to be_present
        expect(select_html[/<option selected="selected" value="([a-z]+)"/, 1]).to eq(page_privacy)
      end
    end
  end

  describe 'standalone block creation' do
    it 'keeps the model default (private) with no page context' do
      expect(BetterTogether::Content::Hero.new.privacy).to eq('private')
    end
  end

  describe 'persisting block privacy' do
    let(:locale) { I18n.default_locale }

    before { grant_content_publishing_agreement(user.person) }

    it 'saves the privacy set on a block through the page form' do
      page = create(:better_together_page, :private, protected: false,
                                                     title: 'Privacy Coverage Page', content: 'Body')
      block = create(:better_together_content_image)
      page_block = page.page_blocks.create!(block:, position: 0)

      patch better_together.page_path(page, locale:), params: {
        page: {
          title_en: page.title,
          content_en: page.content.to_plain_text,
          page_blocks_attributes: [
            { id: page_block.id, position: 0,
              block_attributes: { id: block.id, privacy: 'community' } }
          ]
        }
      }

      expect(response).to be_redirect
      expect(block.reload.privacy).to eq('community')
    end

    it 'saves the privacy set on a block through the standalone block form' do
      block = create(:better_together_content_image)

      patch better_together.content_block_path(block), params: { block: { privacy: 'community' } }

      expect(response).to redirect_to(better_together.content_block_path(block))
      expect(block.reload.privacy).to eq('community')
    end
  end
end
