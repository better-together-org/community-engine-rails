# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::TrackPageViewJob do
  describe 'UTF-8 URL handling' do
    let(:person) { create(:better_together_person) }
    let(:pageable) { create(:better_together_page, content: 'Test page content') }

    let(:utf8_urls) do
      [
        'https://example.com/café', # UTF-8 path
        'https://example.com/页面', # Chinese characters in path
        'https://bücher.example.com/straße' # German umlauts
      ]
    end

    it 'creates PageView records without errors' do
      # Test that the job can create page views successfully
      # The UTF-8 handling is tested at the model level
      expect do
        described_class.perform_now(pageable, 'en')
      end.to change(BetterTogether::Metrics::PageView, :count).by(1)

      page_view = BetterTogether::Metrics::PageView.last
      expect(page_view).to be_valid
      expect(page_view.errors[:page_url]).to be_empty
    end

    context 'handles pageables with UTF-8 URLs' do
      it 'creates page view when page URL contains UTF-8 characters' do
        # Create a page view with a UTF-8 URL
        page_view = BetterTogether::Metrics::PageView.new(
          viewed_at: Time.current,
          locale: 'en'
        )

        # Set UTF-8 page URL directly - this will be processed by set_page_url
        page_view.assign_attributes(page_url: 'https://例え.テスト/ページ')

        expect(page_view.save).to be true
        expect(page_view.errors[:page_url]).to be_empty
        # The set_page_url method extracts the path and URL-encodes UTF-8 characters
        expect(page_view.page_url).to eq('/%E3%83%9A%E3%83%BC%E3%82%B8')
      end
    end
  end
end
