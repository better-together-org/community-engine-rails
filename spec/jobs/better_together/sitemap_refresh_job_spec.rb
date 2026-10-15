# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SitemapRefreshJob do
  let!(:host_platform) do
    BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host, :public)
  end

  it 'is a valid job' do
    expect(described_class.new).to be_an(BetterTogether::ApplicationJob)
  end

  it 'can be enqueued' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
  end

  describe '.enqueue_unless_pending' do
    it 'enqueues when nothing equivalent is pending' do
      allow(described_class).to receive(:pending?).and_return(false)

      expect { described_class.enqueue_unless_pending(host_platform.id) }
        .to have_enqueued_job(described_class).with(host_platform.id)
    end

    it 'does not enqueue when an equivalent job is pending' do
      allow(described_class).to receive(:pending?).and_return(true)

      expect { described_class.enqueue_unless_pending(host_platform.id) }
        .not_to have_enqueued_job(described_class)
    end
  end

  describe '.pending?' do
    let(:queue_item) do
      lambda do |*arguments|
        { 'wrapped' => described_class.name, 'args' => [{ 'arguments' => arguments }] }
      end
    end

    before { allow(Sidekiq::Workers).to receive(:new).and_return([]) }

    it 'treats a queued full sweep as covering every platform' do
      allow(Sidekiq::Queue).to receive(:new).and_return([double(item: queue_item.call)])

      expect(described_class.pending?(host_platform.id)).to be(true)
      expect(described_class.pending?).to be(true)
    end

    it 'treats a queued scoped job as covering only its platform' do
      allow(Sidekiq::Queue).to receive(:new)
        .and_return([double(item: queue_item.call(host_platform.id))])

      expect(described_class.pending?(host_platform.id)).to be(true)
      expect(described_class.pending?(SecureRandom.uuid)).to be(false)
    end
  end

  describe '#perform' do
    it 'regenerates a single platform when given an id' do
      generator = instance_double(BetterTogether::Sitemaps::Generator, call: %w[en])
      allow(BetterTogether::Sitemaps::Generator).to receive(:new).with(host_platform).and_return(generator)

      described_class.new.perform(host_platform.id)

      expect(generator).to have_received(:call)
    end

    it 'ignores an unknown / external platform id' do
      expect { described_class.new.perform(SecureRandom.uuid) }.not_to raise_error
    end

    it 'sweeps every locally-hosted platform when given no id' do
      create(:better_together_platform, host: false, external: false)
      allow(BetterTogether::Sitemaps::Generator).to receive(:new).and_return(
        instance_double(BetterTogether::Sitemaps::Generator, call: [])
      )

      described_class.new.perform

      expect(BetterTogether::Sitemaps::Generator)
        .to have_received(:new).exactly(BetterTogether::Platform.internal.count).times
    end
  end
end
