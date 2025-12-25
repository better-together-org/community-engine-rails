# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::TrackLinkClickJob do
  describe 'UTF-8 URL handling' do
    let(:utf8_urls) do
      [
        'https://例え.テスト', # Japanese IDN
        'https://тест.рф', # Cyrillic IDN
        'https://example.com/café', # UTF-8 path
        'https://example.com/页面', # Chinese characters in path
        'https://bücher.example.com/straße', # German umlauts
        'https://пример.испытание/тест' # Full Cyrillic URL
      ]
    end

    let(:valid_params) do
      {
        page_url: 'https://example.com/test',
        locale: 'en',
        internal: false
      }
    end

    it 'creates LinkClick records for UTF-8 URLs without errors' do
      utf8_urls.each do |url|
        expect do
          described_class.perform_now(
            url,
            valid_params[:page_url],
            valid_params[:locale],
            valid_params[:internal]
          )
        end.to change(BetterTogether::Metrics::LinkClick, :count).by(1)

        link_click = BetterTogether::Metrics::LinkClick.last
        expect(link_click.url).to eq(url)
        expect(link_click).to be_valid
      end
    end

    it 'handles UTF-8 page URLs' do
      utf8_urls.each do |page_url|
        expect do
          described_class.perform_now(
            'https://example.com/link',
            page_url,
            'en',
            false
          )
        end.to change(BetterTogether::Metrics::LinkClick, :count).by(1)

        link_click = BetterTogether::Metrics::LinkClick.last
        expect(link_click.page_url).to eq(page_url)
        expect(link_click).to be_valid
      end
    end
  end
end
