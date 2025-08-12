# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Metrics::PageView, type: :model do
    let(:viewed_at) { Time.zone.now }
    let(:locale) { 'en' }

    it 'normalizes page_url to exclude query strings' do
      page_view = described_class.new(
        page_url: 'https://example.com/path?foo=bar',
        viewed_at: viewed_at,
        locale: locale
      )

      expect(page_view).to be_valid
      expect(page_view.page_url).to eq('/path')
    end

    it 'rejects URLs containing sensitive parameters' do
      page_view = described_class.new(
        page_url: 'https://example.com/path?token=abc',
        viewed_at: viewed_at,
        locale: locale
      )

      expect(page_view).not_to be_valid
      expect(page_view.errors[:page_url]).to include('contains sensitive parameters')
    end
  end
end
