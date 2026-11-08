# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/cli'

# The dummy app's Sidekiq config is the reference host configuration for the
# billing queue (see docs/production/billing_queue_rollout.md). It is parsed with
# Sidekiq's own config reader and queue/capsule logic, so these examples check what
# Sidekiq will actually do rather than a reading of the YAML.
RSpec.describe 'Billing Sidekiq queue configuration' do # rubocop:disable RSpec/DescribeClass
  let(:path) { BetterTogether::Engine.root.join('spec/dummy/config/sidekiq.yml').to_s }
  let(:cli) { Sidekiq::CLI.instance }
  let(:options) { cli.send(:parse_config, path) }
  let(:sidekiq_config) { Sidekiq::Config.new }

  # The CLI singleton has no environment until Sidekiq boots; parse_config merges
  # the block for that environment, so name one.
  before { allow(cli).to receive(:environment).and_return('test') }

  def capsule_for(name, queues, concurrency: 1)
    sidekiq_config.capsule(name) do |capsule|
      capsule.queues = queues
      capsule.concurrency = concurrency
    end
  end

  describe 'the shared worker queue list' do
    subject(:capsule) { capsule_for('shared', options.fetch(:queues)) }

    it 'polls the billing queue more often than any other queue' do
      weights = capsule.weights

      expect(capsule.mode).to eq(:weighted)
      expect(weights.fetch('billing')).to be > weights.except('billing').values.max
    end

    it 'keeps the other queues that were already configured' do
      expect(capsule.weights.keys).to include('default', 'maintenance', 'notifications', 'platform_sync', 'webhooks')
    end
  end

  describe 'the dedicated billing capsule' do
    let(:capsule_options) { options.fetch(:capsules).fetch(:billing) }
    let(:capsule) { capsule_for('billing', capsule_options.fetch(:queues), concurrency: capsule_options.fetch(:concurrency)) }

    it 'works only the billing queue, with threads reserved for it' do
      expect(capsule.weights.keys).to eq(['billing'])
      expect(capsule.concurrency).to be >= 1
    end
  end

  it 'resolves the same configuration in every environment block' do
    %w[development test production].each do |environment|
      allow(cli).to receive(:environment).and_return(environment)

      expect(cli.send(:parse_config, path).fetch(:queues)).to include(['billing', 10])
    end
  end
end
