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

    it 'handles pageables with UTF-8 URLs' do
      # Create a mock pageable that returns UTF-8 URL
      utf8_pageable = instance_double(Page)
      allow(utf8_pageable).to receive_messages(url: 'https://example.com/café', becomes: utf8_pageable,
                                               class: double(base_class: double)) # rubocop:todo RSpec/VerifiedDoubles

      expect do
        described_class.perform_now(utf8_pageable, 'en')
      end.to change(BetterTogether::Metrics::PageView, :count).by(1)

      page_view = BetterTogether::Metrics::PageView.last
      expect(page_view.errors[:page_url]).to be_empty
    end
  end
end
