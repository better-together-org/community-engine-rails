# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Metrics::PageView do
    let(:viewed_at) { Time.zone.now }
    let(:locale) { 'en' }

    # rubocop:todo RSpec/MultipleExpectations
    it 'normalizes page_url to exclude query strings' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      page_view = described_class.new(
        page_url: 'http://127.0.0.1:3000/path?foo=bar',
        viewed_at: viewed_at,
        locale: locale
      )

      expect(page_view).to be_valid
      expect(page_view.page_url).to eq('/path')
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'rejects URLs containing sensitive parameters' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      page_view = described_class.new(
        page_url: 'http://127.0.0.1:3000/path?token=abc',
        viewed_at: viewed_at,
        locale: locale
      )

      expect(page_view).not_to be_valid
      expect(page_view.errors[:page_url]).to include('contains sensitive parameters')
    end
  end
end
