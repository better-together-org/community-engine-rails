# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::TrackLinkClickJob do
  describe '#perform' do
    let(:url) { 'https://example.com' }
    let(:page_url) { 'https://mysite.com/page' }
    let(:locale) { 'en' }
    let(:internal) { false }

    it 'creates a LinkClick record' do
      expect do
        described_class.new.perform(url, page_url, locale, internal)
      end.to change(BetterTogether::Metrics::LinkClick, :count).by(1)
    end

    it 'sets the url correctly' do
      described_class.new.perform(url, page_url, locale, internal)
      link_click = BetterTogether::Metrics::LinkClick.last
      expect(link_click.url).to eq(url)
    end

    it 'sets the page_url correctly' do
      described_class.new.perform(url, page_url, locale, internal)
      link_click = BetterTogether::Metrics::LinkClick.last
      expect(link_click.page_url).to eq(page_url)
    end

    it 'sets the locale correctly' do
      described_class.new.perform(url, page_url, locale, internal)
      link_click = BetterTogether::Metrics::LinkClick.last
      expect(link_click.locale).to eq(locale)
    end

    it 'sets the internal flag correctly' do
      described_class.new.perform(url, page_url, locale, true)
      link_click = BetterTogether::Metrics::LinkClick.last
      expect(link_click.internal).to be true
    end

    it 'sets clicked_at to current time' do
      described_class.new.perform(url, page_url, locale, internal)
      link_click = BetterTogether::Metrics::LinkClick.last
      expect(link_click.clicked_at).to be_within(1.second).of(Time.current)
    end

    it 'enqueues the job' do
      expect do
        described_class.perform_later(url, page_url, locale, internal)
      end.to have_enqueued_job(described_class).with(url, page_url, locale, internal)
    end

    it 'uses the metrics queue' do
      expect(described_class.new.queue_name).to eq('metrics')
    end
  end
end
