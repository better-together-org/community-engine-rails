# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::TrackPageViewJob do
  describe '#perform' do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
    let(:page) { create(:page) }
    let(:locale) { 'en' }
    let(:logged_in) { true }

    it 'creates a PageView record' do
      expect do
        described_class.new.perform(page, locale, host_platform.id, logged_in)
      end.to change(BetterTogether::Metrics::PageView, :count).by(1)
    end

    it 'sets the pageable correctly' do
      described_class.new.perform(page, locale, host_platform.id, logged_in)
      page_view = BetterTogether::Metrics::PageView.last
      expect(page_view.pageable).to eq(page)
    end

    it 'sets the locale correctly' do
      described_class.new.perform(page, locale, host_platform.id, logged_in)
      page_view = BetterTogether::Metrics::PageView.last
      expect(page_view.locale).to eq(locale)
    end

    it 'stores platform and logged-in state' do
      described_class.new.perform(page, locale, host_platform.id, logged_in)
      page_view = BetterTogether::Metrics::PageView.last

      expect(page_view.platform).to eq(host_platform)
      expect(page_view.logged_in).to be(true)
    end

    it 'sets viewed_at to current time' do
      described_class.new.perform(page, locale, host_platform.id, logged_in)
      page_view = BetterTogether::Metrics::PageView.last
      expect(page_view.viewed_at).to be_within(1.second).of(Time.current)
    end

    it 'enqueues the job' do
      expect do
        described_class.perform_later(page, locale, host_platform.id, logged_in)
      end.to have_enqueued_job(described_class).with(page, locale, host_platform.id, logged_in)
    end

    it 'uses the metrics queue' do
      expect(described_class.new.queue_name).to eq('metrics')
    end
  end
end
