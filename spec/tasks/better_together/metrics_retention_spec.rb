# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'better_together:metrics:retention rake task', type: :task do
  before do
    Rake.application&.clear
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/better_together/metrics_retention.rake')
    Rake::Task.define_task(:environment)
  end

  after do
    ENV.delete('RAW_METRICS_DAYS')
    ENV.delete('REPORT_DAYS')
    ENV.delete('DRY_RUN')
    Rake.application&.clear
  end

  let(:task) { Rake::Task['better_together:metrics:retention'] }
  let(:service) { instance_double(BetterTogether::Metrics::RetentionService, call: { dry_run: false }) }

  it 'runs the retention service with defaults' do
    task.reenable

    allow(BetterTogether::Metrics::RetentionService).to receive(:new).with(
      raw_metrics_days: BetterTogether::Metrics::RetentionService::DEFAULT_RAW_METRICS_DAYS,
      report_days: BetterTogether::Metrics::RetentionService::DEFAULT_REPORT_DAYS,
      dry_run: nil
    ).and_return(service)

    expect(BetterTogether::Metrics::RetentionService).to receive(:new).with(
      raw_metrics_days: BetterTogether::Metrics::RetentionService::DEFAULT_RAW_METRICS_DAYS,
      report_days: BetterTogether::Metrics::RetentionService::DEFAULT_REPORT_DAYS,
      dry_run: nil
    )

    expect { task.invoke }.to output(include('"dry_run": false')).to_stdout
  end

  it 'passes environment overrides to the service' do
    task.reenable

    ENV['RAW_METRICS_DAYS'] = '45'
    ENV['REPORT_DAYS'] = '12'
    ENV['DRY_RUN'] = 'true'

    allow(BetterTogether::Metrics::RetentionService).to receive(:new).with(
      raw_metrics_days: '45',
      report_days: '12',
      dry_run: true
    ).and_return(service)

    expect(BetterTogether::Metrics::RetentionService).to receive(:new).with(
      raw_metrics_days: '45',
      report_days: '12',
      dry_run: true
    )

    task.invoke
  end
end
