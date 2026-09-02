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
end
