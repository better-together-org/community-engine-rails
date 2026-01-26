# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::TrackShareJob do
  describe '#perform' do
    let(:platform) { 'facebook' }
    let(:url) { 'https://example.com' }
    let(:locale) { 'en' }

    context 'without shareable' do
      it 'creates a Share record without shareable' do
        expect do
          described_class.new.perform(platform, url, locale, nil, nil)
        end.to change(BetterTogether::Metrics::Share, :count).by(1)
      end

      it 'sets the platform correctly' do
        described_class.new.perform(platform, url, locale, nil, nil)
        share = BetterTogether::Metrics::Share.last
        expect(share.platform).to eq(platform)
      end

      it 'sets the url correctly' do
        described_class.new.perform(platform, url, locale, nil, nil)
        share = BetterTogether::Metrics::Share.last
        expect(share.url).to eq(url)
      end

      it 'sets the locale correctly' do
        described_class.new.perform(platform, url, locale, nil, nil)
        share = BetterTogether::Metrics::Share.last
        expect(share.locale).to eq(locale)
      end

      it 'sets shared_at to current time' do
        described_class.new.perform(platform, url, locale, nil, nil)
        share = BetterTogether::Metrics::Share.last
        expect(share.shared_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'with allowed shareable' do
      let(:page) { create(:page) }

      it 'creates a Share record with shareable' do
        expect do
          described_class.new.perform(platform, url, locale, 'BetterTogether::Page', page.id)
        end.to change(BetterTogether::Metrics::Share, :count).by(1)
      end

      it 'associates the shareable correctly' do
        described_class.new.perform(platform, url, locale, 'BetterTogether::Page', page.id)
        share = BetterTogether::Metrics::Share.last
        expect(share.shareable).to eq(page)
      end
    end

    context 'with disallowed shareable type' do
      it 'does not create a Share record' do
        expect do
          described_class.new.perform(platform, url, locale, 'BetterTogether::Person', '123')
        end.not_to change(BetterTogether::Metrics::Share, :count)
      end
    end

    it 'enqueues the job' do
      expect do
        described_class.perform_later(platform, url, locale, nil, nil)
      end.to have_enqueued_job(described_class).with(platform, url, locale, nil, nil)
    end

    it 'uses the metrics queue' do
      expect(described_class.new.queue_name).to eq('metrics')
    end
  end
end
