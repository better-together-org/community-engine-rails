# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SitemapRefreshJob do
  let(:host_platform) { create(:platform, :host) }

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
end
