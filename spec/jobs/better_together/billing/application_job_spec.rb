# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ApplicationJob do
  let(:expected_queue) do
    [ActiveJob::Base.queue_name_prefix.presence, 'billing'].compact.join(ActiveJob::Base.queue_name_delimiter)
  end

  def billing_job_classes
    Zeitwerk::Loader.eager_load_namespace(BetterTogether::Billing)
    described_class.descendants
  end

  it 'runs on the billing queue, with the host queue prefix applied' do
    expect(described_class.new.queue_name).to eq(expected_queue)
  end

  # Fails for a future billing job that inherits BetterTogether::ApplicationJob
  # directly and would land on a shared queue.
  it 'is the base of every job class defined under the billing job namespace' do
    files = Dir[BetterTogether::Engine.root.join('app/jobs/better_together/billing/*.rb')]
    names = files.map { |file| "BetterTogether::Billing::#{File.basename(file, '.rb').camelize}" }
    classes = names.map(&:constantize)

    expect(classes - [described_class]).to all(satisfy { |klass| klass < described_class })
  end

  it 'puts every billing job on the billing queue' do
    expect(billing_job_classes.map { |klass| klass.new.queue_name }.uniq - [expected_queue]).to be_empty
  end

  # sidekiq-scheduler enqueues an ActiveJob class with `enqueue(queue: config['queue'])`,
  # which sets the queue name literally and skips the host's queue_name_prefix. A
  # `queue:` key on a scheduled billing job would therefore land in an unprefixed queue
  # that a prefixed host never works. The job class decides instead.
  it 'schedules billing jobs without a queue key, so the job class and queue prefix decide' do
    schedule = YAML.safe_load_file(BetterTogether::Engine.root.join('config/sidekiq_scheduler.yml'), aliases: true)
    billing_entries = schedule.select { |_name, entry| entry['class'].to_s.start_with?('BetterTogether::Billing::') }

    expect(billing_entries.values.pluck('queue').compact).to be_empty
    expect(billing_entries.values.pluck('class').map(&:constantize)).to all(satisfy { |job| job < described_class })
  end
end
