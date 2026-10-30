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

  it 'schedules billing jobs only on the billing queue' do
    schedule = YAML.safe_load_file(BetterTogether::Engine.root.join('config/sidekiq_scheduler.yml'), aliases: true)
    billing_entries = schedule.select { |_name, entry| entry['class'].to_s.start_with?('BetterTogether::Billing::') }

    expect(billing_entries.values.pluck('queue').uniq - ['billing', nil]).to be_empty
  end
end
