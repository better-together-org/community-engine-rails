# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::TrackPageViewJob, 'Platform tracking' do
  let(:platform) { create(:better_together_platform, :host) }
  let(:locale) { I18n.default_locale }

  describe 'tracking platform page views' do
    it 'creates a page view with URL for Platform' do
      expect do
        described_class.perform_now(platform, locale)
      end.to change(BetterTogether::Metrics::PageView, :count).by(1)

      page_view = BetterTogether::Metrics::PageView.last
      expect(page_view.pageable).to eq(platform)
      expect(page_view.page_url).to be_present
      expect(page_view.page_url).to include('/platforms/')
      expect(page_view.page_url).to include(platform.slug)
    end

    it 'stores only the path component of the URL' do
      described_class.perform_now(platform, locale)

      page_view = BetterTogether::Metrics::PageView.last
      # page_url should be just the path, not a full URL
      expect(page_view.page_url).to start_with('/')
      expect(page_view.page_url).not_to include('http')
    end
  end
end
