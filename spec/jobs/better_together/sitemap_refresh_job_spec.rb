# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SitemapRefreshJob do
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  before do
    # Stub search engine ping to prevent actual HTTP requests
    stub_request(:get, %r{google.com/webmasters/tools/ping}).to_return(status: 200, body: '', headers: {})
    host_platform # ensure host platform exists
  end

  it 'is a valid job' do
    expect(described_class.new).to be_an(BetterTogether::ApplicationJob)
  end

  it 'can be enqueued' do
    expect do
      described_class.perform_later
    end.to have_enqueued_job(described_class)
  end

  describe '.enqueue_unless_pending' do
    it 'enqueues when no sitemap refresh job is pending' do
      allow(described_class).to receive(:pending?).and_return(false)

      expect do
        described_class.enqueue_unless_pending
      end.to have_enqueued_job(described_class)
    end

    it 'does not enqueue when a sitemap refresh job is already pending' do
      allow(described_class).to receive(:pending?).and_return(true)

      expect do
        described_class.enqueue_unless_pending
      end.not_to have_enqueued_job(described_class)
    end
  end

  describe '#perform' do
    it 'loads and invokes the sitemap:refresh rake task' do
      # Stub the rake task to avoid complex environment setup
      rake_task = instance_double(Rake::Task)
      allow(Rake::Task).to receive(:task_defined?).with('sitemap:refresh').and_return(true)
      allow(Rake::Task).to receive(:[]).with('sitemap:refresh').and_return(rake_task)
      allow(rake_task).to receive(:invoke)
      allow(rake_task).to receive(:reenable)

      described_class.new.perform

      expect(rake_task).to have_received(:invoke)
      expect(rake_task).to have_received(:reenable)
    end
  end

  describe '.pending?' do
    it 'returns true when the job is already enqueued' do
      queue = instance_double(Sidekiq::Queue)
      allow(Sidekiq::Queue).to receive(:new).with('default').and_return(queue)
      allow(queue).to receive(:any?).and_yield(double(item: { 'wrapped' => described_class.name }))
      allow(Sidekiq::Workers).to receive(:new).and_return([])

      expect(described_class.pending?).to be(true)
    end

    it 'returns true when the job is already running' do
      queue = instance_double(Sidekiq::Queue)
      workers = [[nil, nil, double(job: { 'wrapped' => described_class.name })]]
      allow(Sidekiq::Queue).to receive(:new).with('default').and_return(queue)
      allow(queue).to receive(:any?).and_return(false)
      allow(Sidekiq::Workers).to receive(:new).and_return(workers)

      expect(described_class.pending?).to be(true)
    end
  end
end
