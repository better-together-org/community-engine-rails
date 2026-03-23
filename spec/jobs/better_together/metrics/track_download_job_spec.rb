# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::TrackDownloadJob do
  describe '#perform' do
    let(:page) { create(:page) }
    let(:file_name) { 'document.pdf' }
    let(:file_type) { 'application/pdf' }
    let(:file_size) { 1024 }
    let(:locale) { 'en' }

    it 'creates a Download record' do
      expect do
        described_class.new.perform(page, file_name, file_type, file_size, locale)
      end.to change(BetterTogether::Metrics::Download, :count).by(1)
    end

    it 'sets the downloadable correctly' do
      described_class.new.perform(page, file_name, file_type, file_size, locale)
      download = BetterTogether::Metrics::Download.last
      expect(download.downloadable).to eq(page)
    end

    it 'sets the file_name correctly' do
      described_class.new.perform(page, file_name, file_type, file_size, locale)
      download = BetterTogether::Metrics::Download.last
      expect(download.file_name).to eq(file_name)
    end

    it 'sets the file_type correctly' do
      described_class.new.perform(page, file_name, file_type, file_size, locale)
      download = BetterTogether::Metrics::Download.last
      expect(download.file_type).to eq(file_type)
    end

    it 'sets the file_size correctly' do
      described_class.new.perform(page, file_name, file_type, file_size, locale)
      download = BetterTogether::Metrics::Download.last
      expect(download.file_size).to eq(file_size)
    end

    it 'sets the locale correctly' do
      described_class.new.perform(page, file_name, file_type, file_size, locale)
      download = BetterTogether::Metrics::Download.last
      expect(download.locale).to eq(locale)
    end

    it 'sets downloaded_at to current time' do
      described_class.new.perform(page, file_name, file_type, file_size, locale)
      download = BetterTogether::Metrics::Download.last
      expect(download.downloaded_at).to be_within(1.second).of(Time.current)
    end

    it 'enqueues the job' do
      expect do
        described_class.perform_later(page, file_name, file_type, file_size, locale)
      end.to have_enqueued_job(described_class).with(page, file_name, file_type, file_size, locale)
    end

    it 'uses the metrics queue' do
      expect(described_class.new.queue_name).to eq('metrics')
    end
  end
end
