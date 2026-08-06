# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::TrackShareJob do
  describe '#perform' do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
    let(:platform_name) { 'facebook' }
    let(:url) { 'https://example.com' }
    let(:locale) { 'en' }
    let(:logged_in) { true }

    context 'without shareable' do
      it 'creates a Share record without shareable' do
        expect do
          described_class.new.perform(platform_name, url, locale, nil, nil, host_platform.id, logged_in)
        end.to change(BetterTogether::Metrics::Share, :count).by(1)
      end

      it 'sets the platform_name correctly' do
        described_class.new.perform(platform_name, url, locale, nil, nil, host_platform.id, logged_in)
        share = BetterTogether::Metrics::Share.last
        expect(share.platform_name).to eq(platform_name)
      end

      it 'sets the url correctly' do
        described_class.new.perform(platform_name, url, locale, nil, nil, host_platform.id, logged_in)
        share = BetterTogether::Metrics::Share.last
        expect(share.url).to eq(url)
      end

      it 'sets the locale correctly' do
        described_class.new.perform(platform_name, url, locale, nil, nil, host_platform.id, logged_in)
        share = BetterTogether::Metrics::Share.last
        expect(share.locale).to eq(locale)
      end

      it 'sets shared_at to current time' do
        described_class.new.perform(platform_name, url, locale, nil, nil, host_platform.id, logged_in)
        share = BetterTogether::Metrics::Share.last
        expect(share.shared_at).to be_within(1.second).of(Time.current)
      end

      it 'stores platform and logged-in state' do
        described_class.new.perform(platform_name, url, locale, nil, nil, host_platform.id, logged_in)
        share = BetterTogether::Metrics::Share.last

        expect(share.platform_id).to eq(host_platform.id)
        expect(share.logged_in).to be(true)
      end
    end

    context 'with allowed shareable' do
      let(:page) { create(:page) }

      it 'creates a Share record with shareable' do
        expect do
          described_class.new.perform(platform_name, url, locale, 'BetterTogether::Page', page.id, host_platform.id, logged_in)
        end.to change(BetterTogether::Metrics::Share, :count).by(1)
      end

      it 'associates the shareable correctly' do
        described_class.new.perform(platform_name, url, locale, 'BetterTogether::Page', page.id, host_platform.id, logged_in)
        share = BetterTogether::Metrics::Share.last
        expect(share.shareable).to eq(page)
      end
    end

    context 'with disallowed shareable type' do
      it 'does not create a Share record' do
        expect do
          described_class.new.perform(platform_name, url, locale, 'BetterTogether::Person', '123', host_platform.id, logged_in)
        end.not_to change(BetterTogether::Metrics::Share, :count)
      end
    end

    it 'enqueues the job' do
      expect do
        described_class.perform_later(platform_name, url, locale, nil, nil, host_platform.id, logged_in)
      end.to have_enqueued_job(described_class).with(platform_name, url, locale, nil, nil, host_platform.id, logged_in)
    end

    it 'uses the metrics queue' do
      expect(described_class.new.queue_name).to eq('metrics')
    end

    context 'cross-platform viewer context' do
      let(:federated_platform) { create(:better_together_platform, :public, host: false) }
      let(:federated_page) { create(:better_together_page, platform: federated_platform) }

      it "derives platform from the shareable's own platform, not the viewer's current platform context" do
        described_class.new.perform(platform_name, url, locale, 'BetterTogether::Page', federated_page.id, host_platform.id,
                                    logged_in)

        share = BetterTogether::Metrics::Share.last
        expect(share.platform).to eq(federated_platform)
        expect(share.platform).not_to eq(host_platform)
      end
    end
  end
end
