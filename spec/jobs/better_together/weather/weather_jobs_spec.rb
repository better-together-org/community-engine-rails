# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Weather jobs' do # rubocop:disable RSpec/DescribeClass
  include ActiveJob::TestHelper

  let!(:location) { create(:weather_location) }
  let!(:disabled_source) { create(:weather_source, enabled: false) }

  before do
    create(:weather_location, source: disabled_source)
    clear_enqueued_jobs
  end

  it 'refresh scan enqueues only locations of enabled sources' do
    BetterTogether::Weather::RefreshScanJob.perform_now

    expect(BetterTogether::Weather::RefreshLocationJob).to have_been_enqueued.with(location.id).once
    expect(enqueued_jobs.size).to eq(1)
  end

  it 'backfill scan enqueues only locations of enabled sources' do
    BetterTogether::Weather::BackfillScanJob.perform_now

    expect(BetterTogether::Weather::BackfillLocationJob).to have_been_enqueued.with(location.id).once
    expect(enqueued_jobs.size).to eq(1)
  end

  it 'location jobs call the services and ignore missing or disabled locations' do
    allow(BetterTogether::Weather::RefreshLocation).to receive(:call)
    allow(BetterTogether::Weather::BackfillObservations).to receive(:call)

    BetterTogether::Weather::RefreshLocationJob.perform_now(location.id)
    BetterTogether::Weather::BackfillLocationJob.perform_now(location.id)
    BetterTogether::Weather::RefreshLocationJob.perform_now(SecureRandom.uuid)

    expect(BetterTogether::Weather::RefreshLocation).to have_received(:call).once
    expect(BetterTogether::Weather::BackfillObservations).to have_received(:call).once
  end

  it 'purge job runs retention and supports dry runs' do
    expect(BetterTogether::Weather::PurgeJob.perform_now(dry_run: true)).to include(dry_run: true)
  end

  it 'is scheduled in the engine scheduler file on the right queues' do
    schedule = YAML.load_file(BetterTogether::Engine.root.join('config/sidekiq_scheduler.yml'))

    expect(schedule['better_together:weather:refresh_hourly']).to include('queue' => 'weather')
    expect(schedule['better_together:weather:backfill_daily']).to include('queue' => 'weather')
    expect(schedule['better_together:weather:purge_daily']).to include('queue' => 'maintenance')
  end
end
